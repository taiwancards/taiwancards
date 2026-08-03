# frozen_string_literal: true

require_relative "../rake_progress"

namespace(:huayu) do
  desc("Import the NAER bilingual everyday vocabulary")
  task(import_naer: :environment) do
    Huayu::NaerTermImporter.new.call
  end

  desc("Import the MOE 4808 common characters into the lexeme dictionary and enrich them (idempotent, offline)")
  task(import_characters: :environment) do
    pp(Huayu::CharacterSetImporter.new.call)
  end

  desc("Enrich existing character lexemes with radical/decomposition/etymology/definition from Make Me a Hanzi")
  task(enrich_characters: :environment) do
    puts("Enriched #{Huayu::CharacterEnricher.new.call} characters")
  end

  desc("Import the 214 Kangxi radicals and link every character to its canonical radical (idempotent, offline)")
  task(import_radicals: :environment) do
    pp(Huayu::RadicalImporter.new.call)
  end

  desc("Import the official TOCFL 8000 word lists as level-tagged lexemes + collections (idempotent, offline)")
  task(import_tocfl: :environment) do
    pp(Huayu::TocflImporter.new.call)
  end

  desc("Import the TBCL grammar points as study cards and mark which sentences are voiced (idempotent, offline)")
  task(import_grammar: :environment) do
    pp(Huayu::GrammarImporter.new.call)
  end

  desc("Tag every character with its Cangjie 5 code and build the input lookup (idempotent, offline)")
  task(import_cangjie: :environment) do
    pp(Huayu::CangjieImporter.new.call)
  end

  desc("Backfill missing pinyin/zhuyin/English on every lexeme from CC-CEDICT (idempotent, non-destructive)")
  task(enrich_cedict: :environment) do
    pp(Huayu::CedictEnricher.new.call)
  end

  desc("Collect every MOE reading of each 破音字 character and word (idempotent, offline)")
  task(import_readings: :environment) do
    Huayu::ReadingImporter.new.call
  end

  desc("Import the official NAER/TBCL Taiwan graded character & word lists as school levels (idempotent)")
  task(import_tbcl: :environment) do
    pp(Huayu::SchoolLevelImporter.new.call)
  end

  desc("Rank characters & words by Taiwan MOE/TBCL frequency into data.freq_rank (idempotent, offline)")
  task(import_frequency: :environment) do
    pp(Huayu::FrequencyImporter.new.call)
  end

  desc("Backfill missing Russian glosses on every lexeme from the curated ru_glosses.json (non-destructive)")
  task(enrich_ru: :environment) do
    pp(Huayu::RuEnricher.new.call)
  end

  desc("Backfill missing English + Russian glosses from the curated gloss_overrides.json (non-destructive)")
  task(enrich_gloss_overrides: :environment) do
    pp(Huayu::GlossOverrideEnricher.new.call)
  end

  desc("Flag 成語 idioms and apply the curated chengyu.json (idempotent)")
  task(import_chengyu: :environment) do
    pp(Huayu::ChengyuImporter.new.call)
  end

  desc("Import measure words and the classifier-noun index (idempotent)")
  task(import_liangci: :environment) do
    pp(Huayu::LiangciImporter.new.call)
  end

  desc("Apply official parts of speech: TOCFL 詞類 and 重編國語辭典 tags (idempotent)")
  task(import_pos: :environment) do
    pp(Huayu::PosImporter.new.call)
  end

  desc("Import the thesaurus: dictionary synonyms and antonyms, corpus neighbours (idempotent)")
  task(import_thesaurus: :environment) do
    pp(Huayu::ThesaurusImporter.new.call)
  end

  desc("Order every 破音字 character's readings by how often each is used, Taiwanese first (idempotent)")
  task(reorder_readings: :environment) do
    rank = Huayu::ReadingRank.new
    weights = rank.weights
    scope = Lexeme.where(kind: :character).where("jsonb_array_length(data->'readings') > 1")
    total = scope.count
    changed = 0

    RakeProgress.counter(total, "破音字") do |tick|
      scope.find_each do |lexeme|
        ordered = rank.order(lexeme, weights[lexeme.id] || Hash.new(0.0))
        if ordered != lexeme.reading_set
          lexeme.update_columns(readings: ordered.first, data: lexeme.data.merge("readings" => ordered))
          changed += 1
        end
        tick.call
      end
    end

    puts("reading order updated: #{changed}")
  end

  desc("Collapse full-width and stray whitespace in stored readings to a single space (idempotent)")
  task(normalize_readings: :environment) do
    scope = Lexeme.where.not(kind: :sentence)
    total = scope.count
    changed = 0

    RakeProgress.counter(total, "lexemes") do |tick|
      scope.find_each do |lexeme|
        readings = lexeme.readings.transform_values { |value| Huayu::ReadingForms.normalize_zhuyin(value) }
        stored = Array(lexeme.data["readings"]).map { |reading|
          reading.transform_values { |value| Huayu::ReadingForms.normalize_zhuyin(value) }
        }

        updates = {}
        updates[:readings] = readings if readings != lexeme.readings
        updates[:data] = lexeme.data.merge("readings" => stored) if stored.any? && stored != lexeme.data["readings"]

        if updates.any?
          lexeme.update_columns(updates)
          changed += 1
        end

        tick.call
      end
    end

    puts("readings normalised: #{changed}")
  end

  desc("Rebuild the search_text index column on every lexeme (fast, idempotent)")
  task(rebuild_search: :environment) do
    scope = Lexeme.where.not(kind: :sentence)
    total = scope.count
    RakeProgress.counter(total, "lexemes") do |tick|
      scope.find_each do |lexeme|
        lexeme.rebuild_search_text
        lexeme.update_column(:search_text, lexeme.search_text) if lexeme.search_text_changed?
        tick.call
      end
    end
  end

  desc("Recompute the restricted flag on every lexeme from its sources (idempotent)")
  task(flag_restricted: :environment) do
    updated = Huayu::RestrictedFlagger.new.call
    puts("restricted flag recomputed: #{Lexeme.where(restricted: true).count} restricted (#{updated} rows scanned)")
  end

  desc(
    "Re-apply only translations (RU glosses, word overrides, lesson summaries + vocab RU) without re-downloading or re-importing. Fast + idempotent."
  )
  task(refresh_translations: :environment) do
    Rake::Task["huayu:enrich_ru"].invoke
    Rake::Task["huayu:enrich_gloss_overrides"].invoke
    Rake::Task["textbook:load"].invoke
    Rake::Task["textbook:enrich_vocab_ru"].invoke
    Rake::Task["huayu:rebuild_search"].invoke
    Rake::Task["huayu:flag_restricted"].invoke
    puts("translations refreshed")
  end

  namespace(:build) do
    desc(
      "Build/refresh ALL freely-licensed open data (idempotent, downloads if missing). No Textbook, no scraped audio."
    )
    task(open: :environment) do
      started = RakeProgress.clock
      steps = ["lang:zh_tw:fetch_open", "huayu:import_characters", "huayu:import_tbcl", "huayu:import_tocfl", "huayu:import_frequency", "huayu:import_cangjie", "huayu:enrich_characters", "huayu:import_radicals", "huayu:enrich_cedict", "huayu:import_readings", "huayu:enrich_ru", "huayu:enrich_gloss_overrides", "huayu:import_everyday", "huayu:import_common_words", "huayu:compute_difficulty", "huayu:reorder_readings", "huayu:normalize_readings", "huayu:rebuild_search", "huayu:flag_restricted"]
      RakeProgress.banner("Taiwan Huayu · open data", steps.size)
      steps.each_with_index do |name, index|
        RakeProgress.step(index + 1, steps.size, name) { Rake::Task[name].invoke }
      end
      RakeProgress.finish("huayu:build:open", started)
    end

    desc("Add the restricted (license-violating) Textbook lessons, vocabulary and scraped audio on top (idempotent)")
    task(restricted: :environment) do
      started = RakeProgress.clock
      steps = ["textbook:download_audio", "textbook:load", "textbook:import_lexemes", "textbook:enrich_vocab_ru", "huayu:reorder_readings", "huayu:normalize_readings", "huayu:rebuild_search", "huayu:flag_restricted"]
      RakeProgress.banner("Textbook materials", steps.size)
      steps.each_with_index do |name, index|
        RakeProgress.step(index + 1, steps.size, name) { Rake::Task[name].invoke }
      end
      RakeProgress.finish("huayu:build:restricted", started)
    end

    desc("Build everything: open data first, then the restricted Textbook layer")
    task(all: :environment) do
      started = RakeProgress.clock
      Rake::Task["huayu:build:open"].invoke
      Rake::Task["huayu:build:restricted"].invoke
      ContentCache.clear
      puts("derived caches cleared")
      RakeProgress.finish("huayu:build:all", started)
    end
  end
end

namespace :huayu do
  desc "Import Taiwan everyday and slang vocabulary"
  task import_everyday: :environment do
    result = Huayu::TaiwanEverydayImporter.new.call
    puts("Taiwan everyday: #{result.imported} imported, #{result.skipped} skipped, #{result.dropped} unlisted")
  end
end

namespace :huayu do
  desc "Recompute the difficulty score for every character, word and phrase"
  task compute_difficulty: :environment do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    RakeProgress.banner("Difficulty", 1)
    updated = RakeProgress.step(1, 1, "scoring lexemes") { Lexemes::Difficulty.new.call }
    RakeProgress.report("rescored: #{updated}")
    RakeProgress.finish("Difficulty", started)
  end
end

namespace :huayu do
  desc "Recount the dictionary numbers shown on the landing page"
  task refresh_landing: :environment do
    Site::Counts.reset!
    RakeProgress.report(**Site::Counts.fetch)
  end
end
