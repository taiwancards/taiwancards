# frozen_string_literal: true

namespace(:deploy) do
  SYNC_STEPS = [
    {
      name: "textbook",
      task: "textbook:load",
      paths: %w[textbook],
      code: %w[app/services/textbook/lexeme_importer.rb]
    },
    {
      name: "textbook_lexemes",
      task: "textbook:import_lexemes",
      paths: %w[textbook],
      code: %w[app/services/textbook/lexeme_importer.rb app/services/textbook/sentence_extractor.rb]
    },
    {
      name: "content_sources",
      task: "huayu:import_sources",
      paths: %w[content_sources.json],
      code: %w[app/models/content_source.rb]
    },
    {
      name: "taiwan_everyday",
      task: "huayu:import_everyday",
      paths: %w[huayu/taiwan_everyday.json],
      code: %w[app/services/huayu/taiwan_everyday_importer.rb app/services/lexemes/upserter.rb]
    },
    {
      name: "grammar",
      task: "huayu:import_grammar",
      paths: %w[huayu/grammar_lessons.json],
      code: %w[app/services/huayu/grammar_importer.rb app/services/huayu/grammar_lessons.rb]
    },
    {
      name: "voiced_sentences",
      task: "huayu:mark_voiced",
      media_paths: %w[listening/manifest.json],
      code: %w[app/services/huayu/voiced_sentences.rb app/services/huayu/listening_clips.rb]
    },
    {
      name: "common_words",
      task: "huayu:import_common_words",
      paths: %w[huayu/common_words.json],
      code: %w[app/services/huayu/common_words_importer.rb]
    },
    {
      name: "difficulty",
      task: "huayu:compute_difficulty",
      paths: %w[huayu/taiwan_everyday.json huayu/moe_idioms.json],
      code: %w[app/services/lexemes/difficulty.rb]
    },
    {
      name: "ru_glosses",
      task: "huayu:enrich_ru",
      paths: %w[huayu/ru_glosses.json],
      code: %w[app/services/huayu/ru_enricher.rb]
    },
    {
      name: "gloss_overrides",
      task: "huayu:enrich_gloss_overrides",
      paths: %w[huayu/gloss_overrides.json],
      code: %w[app/services/huayu/gloss_override_enricher.rb]
    },
    {
      name: "phrase_drills",
      task: "huayu:import_phrase_drills",
      paths: %w[huayu/phrase_drills.txt huayu/bigram_frequency.json],
      code: %w[
        app/services/huayu/phrase_drills_importer.rb
        app/services/huayu/phrase_levels.rb
        app/services/textbook/lexeme_importer.rb
      ]
    },
    {
      name: "sense_meanings",
      task: "huayu:fill_sense_meanings",
      paths: %w[huayu/sense_glosses.jsonl],
      code: %w[app/services/huayu/sense_meaning_filler.rb]
    },
    {
      name: "collocation_meanings",
      task: "huayu:fill_collocation_meanings",
      paths: %w[huayu/collocation_glosses.jsonl],
      code: %w[app/services/huayu/collocation_meaning_filler.rb]
    },
    {
      name: "sentence_meanings",
      task: "huayu:fill_sentence_meanings",
      paths: %w[huayu/sentence_glosses.jsonl],
      code: %w[app/services/huayu/sentence_meaning_filler.rb]
    },
    {
      name: "chengyu",
      task: "huayu:import_chengyu",
      paths: %w[huayu/moe_idioms.json huayu/chengyu.json],
      code: %w[app/services/huayu/chengyu_importer.rb]
    },
    {
      name: "parts_of_speech",
      task: "huayu:import_pos",
      paths: %w[huayu/parts_of_speech.json],
      code: %w[app/services/huayu/pos_importer.rb]
    },
    {
      name: "thesaurus",
      task: "huayu:import_thesaurus",
      paths: %w[huayu/thesaurus.json],
      code: %w[app/services/huayu/thesaurus_importer.rb]
    },
    {
      name: "liangci",
      task: "huayu:import_liangci",
      paths: %w[huayu/measure_words.json huayu/classifier_pairs.json],
      code: %w[app/services/huayu/liangci_importer.rb]
    },
    {
      name: "register_mix",
      task: "huayu:register_mix",
      paths: %w[content_sources.json],
      code: %w[app/services/lexemes/register_mix.rb]
    },
    {
      name: "segmentation",
      task: "huayu:resegment",
      paths: %w[huayu/bigram_frequency.json huayu/segmentation_vocab.json],
      code: %w[app/services/huayu/text_analyzer.rb app/services/huayu/bigram_frequency.rb]
    }
  ].freeze

  ALWAYS_STEPS = {
    "kind_merge" => -> {
      merge = Lexemes::KindMerge.new
      next :skipped unless merge.drift?

      merge.call
      :ran
    },
    "reading_links" => -> {
      linker = Huayu::ReadingLinker.new
      next :skipped unless linker.drift?

      linker.call
      :ran
    },
    "reading_order" => -> {
      order = Lexemes::ReadingOrder.new
      next :skipped unless order.drift?

      $stdout.puts(order.call.to_s)
      :ran
    },
    "sense_order" => -> {
      order = Lexemes::SenseOrder.new
      next :skipped unless order.drift?

      order.call
      :ran
    },
    "sentence_brackets" => -> {
      repair = Huayu::SentenceBracketRepair.new
      next :skipped unless repair.drift?

      $stdout.puts(repair.call.to_s)
      :ran
    },
    "sentence_profiles" => -> {
      stale = Huayu::SentenceProfiler.stale
      next :skipped unless stale.exists?

      Huayu::SentenceProfiler.new(scope: stale).call
      :ran
    },
    "character_glosses" => -> {
      repair = Huayu::CharacterGlossRepair.new
      next :skipped unless repair.drift?

      $stdout.puts(repair.call.to_s)
      :ran
    },
    "admin_rights" => -> {
      result = Accounts::Owner.new.call
      next :skipped unless result.changed?

      $stdout.puts(result.to_s)
      :ran
    },
    "flag_restricted" => -> {
      flagger = Huayu::RestrictedFlagger.new
      next :skipped unless flagger.drift?

      flagger.call
      :ran
    },
    "sentence_case" => -> {
      caser = Lexemes::SentenceCase.new
      next :skipped unless caser.drift?

      caser.call
      :ran
    },
    "landing_counts" => -> {
      Site::Counts.warm!
      :ran
    },
    "syllable_index" => -> {
      Rails.cache.delete("pron:syllable_index")
      Pronunciation::SyllableIndex.for
      :ran
    },
    "prune_activity" => -> {
      ActivityEvent.prune_all.zero? ? :skipped : :ran
    }
  }.freeze

  WARMING_STEPS = %w[landing_counts syllable_index prune_activity].freeze

  FILLERS = %w[
    Huayu::GlossOverrideEnricher
    Huayu::SenseMeaningFiller
    Huayu::CollocationMeaningFiller
    Huayu::ChengyuImporter
    Huayu::PosImporter
    Huayu::LiangciImporter
    Huayu::ThesaurusImporter
    Lexemes::RegisterMix
  ].freeze

  STEP_TIMER = lambda do |name, &block|
    $stdout.puts("deploy:sync → #{name}")
    $stdout.flush
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = block.call
    $stdout.puts("deploy:sync ← #{name} (#{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(2)}s)")
    $stdout.flush
    result
  end

  RECOVER = lambda do
    ActiveRecord::Base.connection.verify!
    MaintenanceWindow.open!
  rescue => e
    warn("deploy:sync could not restore the database connection: #{e.class}: #{e.message}")
  end

  desc("Import committed data sources that changed since the last boot (idempotent, no-op when unchanged)")
  task(sync: :environment) do
    started = Time.current
    ran = []
    skipped = []
    failed = []

    MaintenanceWindow.open!

    SYNC_STEPS.each do |step|
      sources = step[:paths].to_a.map { |relative| AppData.path(relative) } +
        step[:media_paths].to_a.map { |relative| AppData.media_path(relative) }
      next skipped << "#{step[:name]} (absent)" if sources.none?(&:exist?)

      code = step[:code].to_a.map { |relative| Rails.root.join(relative) }
      guard = Deploy::SyncGuard.new(step[:name], sources + code)
      next skipped << step[:name] unless guard.stale?

      begin
        STEP_TIMER.call(step[:name]) { Rake::Task[step[:task]].invoke }
        guard.remember!
        ran << step[:name]
      rescue => e
        failed << "#{step[:name]} (#{e.class})"
        warn("deploy:sync step #{step[:name]} failed: #{e.class}: #{e.message}")
        RECOVER.call
      end
    end

    ALWAYS_STEPS.each do |name, action|
      STEP_TIMER.call(name) { action.call } == :skipped ? skipped << name : ran << name
    rescue => e
      failed << "#{name} (#{e.class})"
      warn("deploy:sync step #{name} failed: #{e.class}: #{e.message}")
      RECOVER.call
    end

    if (ran - WARMING_STEPS).any?
      begin
        STEP_TIMER.call("derived_caches") do
          ContentCache.clear
          Site::Counts.warm!
          Pronunciation::SyllableIndex.for
        end
        ran << "derived_caches"
      rescue => e
        failed << "derived_caches (#{e.class})"
        warn("deploy:sync step derived_caches failed: #{e.class}: #{e.message}")
      end
    else
      skipped << "derived_caches"
    end

    elapsed = (Time.current - started).round(2)
    report = "deploy:sync ran [#{ran.join(", ")}] · unchanged [#{skipped.join(", ")}] (#{elapsed}s)"
    report += " · FAILED [#{failed.join(", ")}]" if failed.any?
    puts(report)
  end

  desc("Download everything the running app reads from the runtime bucket. Usage: rake deploy:hydrate")
  task(hydrate: :environment) do
    Deploy::Hydrator.new.call
  end

  desc("Fill glosses, parts of speech and register mix from the dictionary already in the database")
  task(fillers: :environment) do
    MaintenanceWindow.open!

    failed = FILLERS.filter_map do |name|
      service = name.safe_constantize
      next puts("#{name}: not in this build") if service.nil?

      begin
        puts("#{name}: #{service.new.call.inspect}")
        nil
      rescue => e
        warn("#{name} failed: #{e.class}: #{e.message}")
        "#{name} (#{e.class})"
      end
    end

    abort("deploy:fillers FAILED [#{failed.join(", ")}]") if failed.any?
  end

  desc("Ask Render to build and roll out the current commit. Usage: rake deploy:release")
  task(release: :environment) do
    deploy = Render::Api.new.deploy!
    puts("release: #{deploy.fetch("id")} #{deploy.fetch("status")} — watch it in the Render dashboard")
  end
end
