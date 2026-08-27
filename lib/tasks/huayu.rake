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

  desc("Import the TBCL grammar points as study cards (idempotent, offline)")
  task(import_grammar: :environment) do
    pp(Huayu::GrammarImporter.new.call)
  end

  desc("Load the owner-only reading texts from reading_stories.json (idempotent, offline)")
  task(import_stories: :environment) do
    pp(Huayu::ReadingStories.new.call)
  end

  desc("Mark the sentences that have a listening clip, from the listening manifest (idempotent, offline)")
  task(mark_voiced: :environment) do
    pp(Huayu::VoicedSentences.new.call)
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

  desc("Apply the curated Russian etymologies from etymology_ru.json to the characters that have one")
  task(translate_etymologies: :environment) do
    pp(Huayu::EtymologyTranslations.new.call)
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

  desc("Put the senses of every 破音字 in the order of its readings, Taiwanese first (idempotent)")
  task(reorder_senses: :environment) do
    pp(Lexemes::SenseOrder.new.call)
  end

  desc("Merge any lexeme kept twice, once as a word and once as a collocation (idempotent)")
  task(merge_kinds: :environment) do
    pp(Lexemes::KindMerge.new.call)
  end

  desc("Import the thesaurus: dictionary synonyms and antonyms, corpus neighbours (idempotent)")
  task(import_thesaurus: :environment) do
    pp(Huayu::ThesaurusImporter.new.call)
  end

  desc("Order every 破音字 character's readings by how often each is used, Taiwanese first (idempotent)")
  task(reorder_readings: :environment) do
    pp(Lexemes::ReadingOrder.new.call)
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

  desc("Report vocabulary the segmentation model was never trained on and therefore can never choose")
  task(segmentation_drift: :environment) do
    vocabulary = Huayu::TextAnalyzer.vocabulary[:words]
    model = Huayu::BigramFrequency.instance
    unless model.available?
      abort("no bigram model at #{Huayu::BigramFrequency::PATH}")
    end

    blind = vocabulary.reject { |word| model.knows?(word) }
    puts(format("runtime vocabulary   : %7d", vocabulary.size))
    puts(format("model knows          : %7d", vocabulary.size - blind.size))
    puts(format("model has never seen : %7d (%.1f%%)", blind.size, 100.0 * blind.size / [vocabulary.size, 1].max))
    return if blind.empty?

    graded = Lexeme
      .where(kind: %i[word collocation], text: blind)
      .where("jsonb_exists(data, 'tocfl_level') OR (data ->> 'tbcl_grade') IS NOT NULL")
      .order(:text)
      .pluck(:text)

    puts(format("of those, on a TOCFL or TBCL list : %7d", graded.size))
    return if graded.empty?

    gate = Huayu::TextGate.instance
    outside, missing = graded.partition { |word| !gate.call(word).ok }

    puts(format("  excluded from the corpus by our own gate : %7d", outside.size))
    puts(format("  absent for no stated reason              : %7d", missing.size))
    outside.first(10).each_slice(10) { |slice| puts("\nrightly outside Taiwan usage:\n  #{slice.join(" ")}") }
    return if missing.empty?

    puts("\ncurriculum words the segmenter cannot favour:")
    missing.first(40).each_slice(10) { |slice| puts("  #{slice.join(" ")}") }
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
      steps = [
        "lang:zh_tw:fetch_open",
        "huayu:import_characters",
        "huayu:import_tbcl",
        "huayu:import_tocfl",
        "huayu:import_frequency",
        "huayu:import_cangjie",
        "huayu:enrich_characters",
        "huayu:import_radicals",
        "huayu:enrich_cedict",
        "huayu:import_readings",
        "huayu:enrich_ru",
        "huayu:enrich_gloss_overrides",
        "huayu:import_everyday",
        "huayu:import_medicine",
        "huayu:import_games",
        "huayu:import_common_words",
        "huayu:compute_difficulty",
        "huayu:reorder_readings",
        "huayu:normalize_readings",
        "huayu:rebuild_search",
        "huayu:flag_restricted"
      ]
      RakeProgress.banner("Taiwan Huayu · open data", steps.size)
      steps.each_with_index do |name, index|
        RakeProgress.step(index + 1, steps.size, name) { Rake::Task[name].invoke }
      end

      RakeProgress.finish("huayu:build:open", started)
    end

    desc("Add the restricted (license-violating) Textbook lessons, vocabulary and scraped audio on top (idempotent)")
    task(restricted: :environment) do
      started = RakeProgress.clock
      steps = [
        "textbook:download_audio",
        "textbook:load",
        "textbook:import_lexemes",
        "textbook:enrich_vocab_ru",
        "huayu:reorder_readings",
        "huayu:normalize_readings",
        "huayu:rebuild_search",
        "huayu:flag_restricted"
      ]
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

namespace(:huayu) do
  desc("Import Taiwan everyday and slang vocabulary")
  task(import_everyday: :environment) do
    result = Huayu::TaiwanEverydayImporter.new.call
    puts("Taiwan everyday: #{result.imported} imported, #{result.skipped} skipped, #{result.dropped} unlisted")
  end

  desc("Import the sentence-final mood particles")
  task(import_particles: :environment) do
    result = Huayu::ParticleImporter.new.call
    puts("mood particles: #{result.imported} imported, #{result.skipped} skipped, #{result.dropped} dropped")
  end

  desc("Import Taiwan medicine, anatomy and hospital vocabulary")
  task(import_medicine: :environment) do
    result = Huayu::MedicineImporter.new.call
    puts("Taiwan medicine: #{result.imported} imported, #{result.skipped} skipped, #{result.dropped} unlisted")
  end

  desc("Import Taiwan board game, mahjong, xiangqi and go vocabulary")
  task(import_games: :environment) do
    result = Huayu::GamesImporter.new.call
    puts("Taiwan games: #{result.imported} imported, #{result.skipped} skipped, #{result.dropped} unlisted")
  end

  desc("Import the everyday vocabulary that song lyrics rely on")
  task(import_song_vocabulary: :environment) do
    result = Huayu::SongVocabularyImporter.new.call
    puts("song vocabulary: #{result.imported} imported, #{result.skipped} skipped")
  end
end

namespace(:huayu) do
  desc("Recompute the difficulty score for every character, word and phrase")
  task(compute_difficulty: :environment) do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    RakeProgress.banner("Difficulty", 1)
    updated = RakeProgress.step(1, 1, "scoring lexemes") { Lexemes::Difficulty.new.call }
    RakeProgress.report("rescored: #{updated}")
    RakeProgress.finish("Difficulty", started)
  end
end

namespace(:huayu) do
  desc("Recount the dictionary numbers shown on the landing page")
  task(refresh_landing: :environment) do
    Site::Counts.reset!
    RakeProgress.report(**Site::Counts.fetch)
  end
end

namespace(:huayu) do
  desc("Import the drill phrases from data/huayu/phrase_drills.txt and rescore difficulty (idempotent, offline)")
  task(import_phrase_drills: :environment) do
    pp(Huayu::PhraseDrillsImporter.new.call)
    pp(Huayu::PhraseLevels.new.call)
    pp(rescored: Lexemes::Difficulty.new.call)
  end
end

namespace(:huayu) do
  desc("Derive an approximate TBCL and TOCFL level for every word and collocation (idempotent, offline)")
  task(derive_levels: :environment) do
    pp(Lexemes::DerivedLevels.new.call)
  end
end
