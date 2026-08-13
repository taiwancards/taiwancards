# frozen_string_literal: true

namespace(:huayu) do
  desc("Import sense inventories and examples from the MOE learner dictionary")
  task(import_senses: :environment) do
    Huayu::SenseImporter.new.call
  end

  desc("Import every corpus sentence, link it to its words, score its difficulty")
  task(import_sentences: :environment) do
    Huayu::SentenceImporter.new(limit: ENV["LIMIT"].presence&.to_i).call
  end

  desc("Turn dictionary collocation examples into collocation lexemes of their own")
  task(import_dictionary_collocations: :environment) do
    Huayu::DictionaryCollocationImporter.new.call
  end

  desc("Fill per-sense meanings: single-sense copy plus our own stored translations")
  task(fill_sense_meanings: :environment) do
    Huayu::SenseMeaningFiller.new.call
  end

  desc("Fill collocation meanings from our own stored translations")
  task(fill_collocation_meanings: :environment) do
    Huayu::CollocationMeaningFiller.new.call
  end

  desc("Audit: assert no sentence survives that a commercial licence does not cover, and remove any that does")
  task(enforce_licences: :environment) do
    result = Licenses::Enforcer.new.call
    puts(format("  sentences left      : %d", result[:sentences_left]))
    puts(format("  source counts zeroed: %d", result[:sources_reset]))
    if result[:sentences_dropped].positive?
      puts(format("  REMOVED %d sentence(s) the importer should never have stored", result[:sentences_dropped]))
    end
  end

  REWRITTEN_TABLES = %w[
    lexemes
    sentence_profiles
    sentence_words
    lexeme_content_sources
    lexeme_links
    lexeme_senses
    sense_examples
    register_samples
  ].freeze

  desc("Reclaim dead tuples and refresh planner statistics on the tables the build rewrites")
  task(compact: :environment) do
    connection = ActiveRecord::Base.connection
    Install::SessionTuning.apply!

    leftovers = connection.select_values(<<~SQL.squish)
      SELECT tablename FROM pg_tables
      WHERE schemaname = 'public' AND (tablename = 'bulk_patch' OR tablename LIKE 'register\\_%patch')
    SQL
    leftovers.each do |table|
      connection.execute("DROP TABLE IF EXISTS #{connection.quote_table_name(table)}")
      puts("  dropped leftover scratch table #{table}")
    end

    size = ->(table) { connection.select_value("SELECT pg_total_relation_size('#{table}')").to_i }
    before = REWRITTEN_TABLES.sum { |table| size.call(table) }

    REWRITTEN_TABLES.each do |table|
      was = size.call(table)
      connection.execute("VACUUM (FULL, ANALYZE) #{table}")
      puts(
        format(
          "  %-24s %s → %s",
          table,
          ActiveSupport::NumberHelper.number_to_human_size(was),
          ActiveSupport::NumberHelper.number_to_human_size(size.call(table))
        )
      )
    end

    connection.execute("ANALYZE")
    after = REWRITTEN_TABLES.sum { |table| size.call(table) }
    puts(
      format(
        "  total %s → %s",
        ActiveSupport::NumberHelper.number_to_human_size(before),
        ActiveSupport::NumberHelper.number_to_human_size(after)
      )
    )
  end

  desc("Collapse template families: keep one sentence per skeleton, drop the copies")
  task(dedupe_template_sentences: :environment) do
    formal = Huayu::FormalSentences.ids

    families = Hash.new { |memo, key| memo[key] = [] }
    Lexeme
      .where(kind: :sentence, id: formal.to_a)
      .select(:id, :text, :score, :meanings)
      .find_each(batch_size: 5000) do |sentence|
        tail = Huayu::SentenceTemplate.tail_key(sentence.text)
        digits = Huayu::SentenceTemplate.digit_key(sentence.text)
        families[[:tail, tail]] << sentence if tail
        families[[:digits, digits]] << sentence if digits
      end

    doomed = Set.new
    kept = 0
    families.each do |(kind, _), members|
      threshold = kind == :tail ? 5 : 3
      next if members.length < threshold

      survivor, *copies = members.sort_by { |s| [s.meanings.present? ? 0 : 1, s.score.to_f] }
      next if doomed.include?(survivor.id)

      kept += 1
      copies.each { |copy| doomed << copy.id }
    end

    doomed.each_slice(500) { |slice| Lexeme.where(id: slice).destroy_all }
    puts("template families: #{kept}, copies dropped: #{doomed.length}")
  end

  desc("Fill sentence meanings from our own stored translations")
  task(fill_sentence_meanings: :environment) do
    Huayu::SentenceMeaningFiller.new.call
  end

  desc("Remove the entries listed as unusable in sentence_rejects.jsonl and collocation_rejects.jsonl. DRY_RUN=1 to only list them")
  task(purge_rejects: :environment) do
    pp(Huayu::RejectPurge.new.call(dry_run: ENV["DRY_RUN"].present?))
  end

  desc("Split single words from collocations using MOE headword status")
  task(classify_collocations: :environment) do
    Huayu::CollocationClassifier.new.call(dry_run: ENV["DRY_RUN"].present?)
  end

  desc("Attach Wiktionary etymology to characters and words we already hold")
  task(import_etymology: :environment) do
    Huayu::EtymologyImporter.new.call
  end

  desc("Load the verified China-marker word list")
  task(import_china_markers: :environment) do
    Huayu::ChinaMarkerImporter.new.call
  end

  desc("Remove dictionary entries that are China usage, erhua included. DRY_RUN=1 to only list them")
  task(purge_china_vocabulary: :environment) do
    pp(Huayu::ChinaVocabularyPurge.new.call(dry_run: ENV["DRY_RUN"].present?))
  end

  desc("Add vocabulary Wiktionary labels as Taiwanese Mandarin")
  task(import_taiwan_vocabulary: :environment) do
    Huayu::TaiwanVocabularyImporter.new.call
  end

  desc("Create character entries for variants used in words and sentences")
  task(supplement_characters: :environment) do
    Huayu::CharacterSupplementer.new.call
  end

  desc("Link words to their characters and collocations to their words")
  task(link_components: :environment) do
    Huayu::ComponentLinker.new.call
  end

  desc("Mark every word→character link with the reading the character takes in that word")
  task(link_readings: :environment) do
    Huayu::ReadingLinker.new.call
  end

  desc("Index which words occur in which sentences, for examples on word pages")
  task(link_sentence_words: :environment) do
    MaintenanceWindow.open!
    Huayu::SentenceWordLinker.new.call
  end

  desc("Re-split every stored sentence with the current segmenter")
  task(resegment: :environment) do
    MaintenanceWindow.open!
    analyzer = Huayu::TextAnalyzer.new
    difficulty = Huayu::SentenceDifficulty.new
    changed = 0
    seen = 0

    Lexeme.where(kind: :sentence).find_in_batches(batch_size: 2000) do |batch|
      batch.each do |sentence|
        tokens = analyzer.segment(sentence.text)
        next if tokens.empty?

        seen += 1
        next if sentence.data["segments"] == tokens

        sentence.update_column(
          :data,
          sentence.data.merge(
            "segments" => tokens,
            "difficulty" => difficulty.call(sentence.text, tokens:)
          )
        )
        changed += 1
      end
      print(".") if (seen % 50_000).zero?
    end

    puts("\nresegmented: #{changed} of #{seen}")
    Rake::Task["huayu:link_sentence_words"].invoke if changed.positive?
  end

  desc("Connect dictionary examples to their sentence records")
  task(link_examples: :environment) do
    Huayu::ExampleLinker.new.call
  end

  desc("Place every sentence on the TOCFL, school-grade and frequency scales")
  task(profile_sentences: :environment) do
    MaintenanceWindow.open!
    Huayu::SentenceProfiler.new.call
  end

  desc("Recompute the level thresholds that drive per-user visibility (idempotent)")
  task(compute_thresholds: :environment) do
    Huayu::ThresholdBuilder.new.call
  end

  desc("Calibrate the expansion ladder against the corpus: exact tolerance per scale and level")
  task(calibrate_ladder: :environment) do
    Huayu::LadderCalibrator.new.call
  end

  desc("Derive per-lexeme speech-style distributions from corpus sentences")
  task(register_mix: :environment) do
    Lexemes::RegisterMix.new.call
  end

  desc("Import the everyday words no official list carries")
  task(import_common_words: :environment) do
    result = Huayu::CommonWordsImporter.new.call
    puts("common words: #{result.imported} added, #{result.skipped} skipped")
  end

  desc("Register the content sources and their licences")
  task(import_sources: :environment) do
    puts("sources: #{ContentSources::Importer.new.call}")
  end

  desc("Rebuild derived content, keeping characters, words and user progress")
  task(refresh: :environment) do
    unless ENV["CONFIRM"] == "yes"
      abort(
        <<~USAGE
          Rebuild derived content.

          KEPT: characters, words, radicals and all user progress —
          cards, reviews, decks.

          REBUILT: collocations, sentences, senses, examples,
          links, levels.

          Run:
            CONFIRM=yes rake huayu:refresh
        USAGE
      )
    end

    started = Time.current
    puts("== Wipe derived ==")
    Content::Wipe.new(full: false).call

    steps = [
      ["huayu:import_sources", "sources and licences"],
      ["huayu:import_taiwan_vocabulary", "Taiwanese vocabulary"],
      ["huayu:import_common_words", "common words outside official lists"],
      ["huayu:import_readings", "full 破音字 reading set"],
      ["huayu:import_senses", "senses and examples"],
      ["huayu:import_dictionary_collocations", "collocations from the MOE dictionary"],
      ["huayu:classify_collocations", "words split from collocations"],
      ["huayu:import_chengyu", "成語 from 教育部《成語典》"],
      ["huayu:import_pos", "parts of speech from official tables"],
      ["huayu:import_thesaurus", "thesaurus: synonyms, antonyms, neighbours"],
      ["huayu:import_etymology", "etymology"],
      ["huayu:import_china_markers", "China vocabulary markers"],
      ["huayu:import_sentences", "sentences"],
      ["huayu:dedupe_template_sentences", "collapse template families"],
      ["huayu:supplement_characters", "supplement character inventory"],
      ["huayu:link_components", "word→character links"],
      ["huayu:link_readings", "character reading inside each word"],
      ["huayu:link_examples", "examples linked to sentences"],
      ["huayu:link_sentence_words", "word→sentence index"],
      ["huayu:profile_sentences", "sentence levels"],
      ["huayu:calibrate_ladder", "calibrate expansion ladder"],
      ["huayu:compute_thresholds", "visibility thresholds"],
      ["huayu:compute_difficulty", "difficulty and 1…999 rating"],
      ["huayu:import_liangci", "measure words and noun index"],
      ["huayu:register_mix", "register mix per lexeme"],
      ["huayu:fill_sense_meanings", "sense glosses in dictionary order"],
      ["huayu:fill_collocation_meanings", "collocation glosses"],
      ["huayu:fill_sentence_meanings", "sentence glosses"],
      ["huayu:reorder_readings", "破音字 reading order by frequency"],
      ["huayu:reorder_senses", "senses follow the reading order"],
      ["huayu:normalize_readings", "reading separators"],
      ["huayu:rebuild_search", "search index"]
    ]

    steps.each_with_index do |(name, title), index|
      puts("\n== [#{index + 1}/#{steps.length}] #{title} ==")
      Rake::Task[name].reenable
      Rake::Task[name].invoke
    end

    puts("\nrebuilt in #{(Time.current - started).round}s")
    Rake::Task["huayu:census"].reenable
    Rake::Task["huayu:census"].invoke
  end

  desc("Build all zh-TW content from scratch. Usage: CONFIRM=yes rake huayu:rebuild")
  task(rebuild: :environment) do
    unless ENV["CONFIRM"] == "yes"
      abort(
        <<~USAGE
          Full content rebuild.

          Wipes EVERYTHING: content, users, cards, decks.
          db:seed recreates the admin.


          Corpora must be in place:
            bash corpora/fetch.sh
            bin/rails runner corpora/export_dict.rb
            bundle exec ruby corpora/parse_concised.rb
            bundle exec ruby corpora/parse_ntpc.rb
            bundle exec ruby corpora/extract_all.rb
            bundle exec ruby corpora/build_corpus_frequency.rb

          Run:
            CONFIRM=yes rake huayu:rebuild
        USAGE
      )
    end

    cards = LexemeMemory.count
    if cards.positive? && ENV["FORCE"] != "yes"
      abort(
        "#{cards} user cards in the database. A full rebuild drops the\n" \
          "characters and words they point at, and the progress goes with them.\n\n" \
          "To rebuild WITHOUT losing progress:\n" \
          "  CONFIRM=yes rake huayu:refresh\n\n" \
          "If the progress really is disposable:\n" \
          "  CONFIRM=yes FORCE=yes rake huayu:rebuild"
      )
    end

    started = Time.current

    puts("== Wipe ==")
    ActiveRecord::Base.transaction { Content::Wipe.new(full: true).call }
    puts(
      "   lexemes: #{Lexeme.count}, cards: #{LexemeMemory.count}, users: #{User.count}"
    )

    ingest_steps = [
      ["db:seed", "settings and admin"],
      ["huayu:import_sources", "sources and licences"],
      ["huayu:build:open", "characters, words, levels, frequency, glosses"],
      ["textbook:load", "textbook lessons from dumps"],
      ["huayu:import_taiwan_vocabulary", "Taiwanese vocabulary from Wiktionary"],
      ["huayu:import_senses", "senses and examples from the MOE dictionary"],
      ["huayu:import_dictionary_collocations", "collocations from the MOE dictionary"],
      ["huayu:classify_collocations", "words split from collocations"],
      ["huayu:import_chengyu", "成語 from 教育部《成語典》"],
      ["huayu:import_pos", "parts of speech from official tables"],
      ["huayu:import_thesaurus", "thesaurus: synonyms, antonyms, neighbours"],
      ["huayu:import_etymology", "etymology"],
      ["huayu:import_china_markers", "China vocabulary markers"],
      ["huayu:import_sentences", "sentences from every corpus"],
      ["huayu:dedupe_template_sentences", "collapse template families"],
      ["huayu:supplement_characters", "supplement character inventory"]
    ]

    derive_steps = [
      ["huayu:link_components", "word→character and collocation→word links"],
      ["huayu:link_readings", "character reading inside each word"],
      ["huayu:link_examples", "examples linked to sentences"],
      ["huayu:link_sentence_words", "word→sentence index"],
      ["huayu:profile_sentences", "sentence levels on three scales"],
      ["huayu:calibrate_ladder", "calibrate expansion ladder against the corpus"],
      ["huayu:compute_thresholds", "visibility thresholds per step"],
      ["huayu:compute_difficulty", "difficulty and 1…999 rating"],
      ["huayu:compact", "reclaim space after the mass rewrites"],
      ["huayu:import_liangci", "measure words and noun index"],
      ["huayu:register_mix", "register mix per lexeme"],
      ["huayu:fill_sense_meanings", "sense glosses in dictionary order"],
      ["huayu:fill_collocation_meanings", "collocation glosses"],
      ["huayu:fill_sentence_meanings", "sentence glosses"],
      ["huayu:reorder_readings", "破音字 reading order by frequency"],
      ["huayu:reorder_senses", "senses follow the reading order"],
      ["huayu:normalize_readings", "reading separators"],
      ["huayu:rebuild_search", "search index"],
      ["huayu:enforce_licences", "drop what no commercial licence covers"],
      ["huayu:compact", "reclaim space after the licence purge"]
    ]

    Install::SessionTuning.apply!
    Install::QueryInterrupt.install!
    RakeProgress.tuning_report(Install::SessionTuning.report)

    run = lambda do |name, _title|
      Rake::Task[name].reenable
      Rake::Task[name].invoke
    end

    heavy = %w[lexemes sentence_words sentence_profiles lexeme_content_sources lexeme_links]
    timings = Deploy::DeferredIndexes.around(heavy) do
      RakeProgress.pipeline(ingest_steps, total: ingest_steps.length + derive_steps.length, &run)
    end

    timings += RakeProgress.pipeline(
      derive_steps,
      offset: ingest_steps.length,
      total: ingest_steps.length + derive_steps.length,
      &run
    )

    RakeProgress.slowest(timings)
    puts("\nbuilt in #{RakeProgress.duration(Time.current - started)}")
    Rake::Task["huayu:census"].reenable
    Rake::Task["huayu:census"].invoke
  end

  desc("Show what is currently in the dictionary")
  task(census: :environment) do
    puts("\nContent")
    Lexeme.group(:kind).count.sort.each do |kind, count|
      puts(format("  %-12s %7d", kind, count))
    end

    puts(format("  %-12s %7d", "senses", LexemeSense.count))
    puts(format("  %-12s %7d", "examples", SenseExample.count))
    puts(format("  %-12s %7d", "links", LexemeLink.count))
    puts(format("  %-12s %7d", "profiles", SentenceProfile.count))

    puts("\nSources")
    ContentSource.ordered.each do |source|
      state = if source.enabled?
        "public"
      else
        source.enabled_for_admins? ? "admins only" : "off"
      end

      count = LexemeContentSource.where(content_source: source).count
      puts(format("  %-16s %-16s %7d  %s", source.slug, state, count, source.license_name))
    end

    puts("\nScale coverage (sentences)")
    SentenceProfile::SCHEMES.each do |scheme, config|
      placed = SentenceProfile.where.not(config[:index] => nil).count
      exact = SentenceProfile.where(config[:exact] => true).count
      puts(format("  %-6s placed %6d, exact %6d", scheme, placed, exact))
    end
  end
end
