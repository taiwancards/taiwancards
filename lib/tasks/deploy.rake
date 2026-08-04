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
      name: "fonts",
      task: "fonts:install",
      paths: %w[fonts.json],
      code: %w[lib/font_assets.rb]
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
      code: %w[app/services/huayu/taiwan_everyday_importer.rb]
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
    }
  ].freeze

  ALWAYS_STEPS = {
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

  LIFT_TIMEOUTS = lambda do
    ActiveRecord::Base.connection.execute("SET statement_timeout = '15min'")
    ActiveRecord::Base.connection.execute("SET lock_timeout = '1min'")
  end

  desc("Import committed data sources that changed since the last boot (idempotent, no-op when unchanged)")
  task(sync: :environment) do
    started = Time.current
    ran = []
    skipped = []
    failed = []

    LIFT_TIMEOUTS.call

    SYNC_STEPS.each do |step|
      sources = step[:paths].to_a.map { |relative| AppData.path(relative) } +
        step[:media_paths].to_a.map { |relative| AppData.media_path(relative) }
      next skipped << "#{step[:name]} (absent)" if sources.none?(&:exist?)

      code = step[:code].to_a.map { |relative| Rails.root.join(relative) }
      guard = Deploy::SyncGuard.new(step[:name], sources + code)
      next skipped << step[:name] unless guard.stale?

      begin
        Rake::Task[step[:task]].invoke
        guard.remember!
        ran << step[:name]
      rescue => e
        failed << "#{step[:name]} (#{e.class})"
        warn("deploy:sync step #{step[:name]} failed: #{e.class}: #{e.message}")
      end
    end

    if ran.any?
      begin
        Rake::Task["deploy:fillers"].invoke
        ran << "fillers"
      rescue => e
        failed << "fillers (#{e.class})"
        warn("deploy:sync fillers failed: #{e.class}: #{e.message}")
      end
    else
      skipped << "fillers"
    end

    ALWAYS_STEPS.each do |name, action|
      action.call == :skipped ? skipped << name : ran << name
    rescue => e
      failed << "#{name} (#{e.class})"
      warn("deploy:sync step #{name} failed: #{e.class}: #{e.message}")
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
    LIFT_TIMEOUTS.call

    failed = Deploy::Rollout::FILLERS.filter_map do |name|
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

  desc("Mirror DATA_ROOT and import whatever changed on it. Run on the server after bin/rebuild-data-render.sh")
  task(refresh: :environment) do
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    ActiveRecord::Base.connection.execute("SET lock_timeout = 0")
    Rake::Task["data:install"].invoke
    Rake::Task["deploy:sync"].invoke
  end

  desc("Ship data/huayu and run only the importers for the files that changed. Usage: rake deploy:glosses")
  task(glosses: :environment) do
    server = ENV["RENDER_SERVER"].presence
    abort("RENDER_SERVER is not set in .env") if server.blank?

    section = Deploy::Catalog.find("huayu")
    abort("data/huayu is missing locally") unless section&.exist?

    dry_run = ENV["DRY_RUN"].present?
    shipper = Content::Shipper.new(server:, region: ENV["RENDER_REGION"].presence)

    puts("━━ 1/2 · data/huayu onto the Render disk ━━")
    shipper.ensure_dirs([section.to]) unless dry_run
    shipper.sync_paths(section.sync_sources, section.to, dry_run:, checksum: ENV["CHECKSUM"].present?)

    puts("\n━━ 2/2 · importers on the server ━━")
    next puts("  skipped: dry run") if dry_run

    shipper.run_remote('cd "${RENDER_PROJECT_DIR:-/opt/render/project/src}"; bundle exec rails deploy:sync')
    puts("\n✓ Done")
  end

  desc(
    "Ship absolutely everything: disk sections, dictionary rows, server tasks. Usage: CONFIRM=yes rake deploy:content"
  )
  task(:content, %i[server region] => :environment) do |_t, args|
    server = args[:server].presence || ENV["RENDER_SERVER"].presence
    if server.blank?
      abort(
        <<~USAGE
          No target Render service. Set it once in .env:
            RENDER_SERVER=srv-xxxxxxxxxxxx
            PROD_DATABASE_URL=postgres://…
          after that:
            CONFIRM=yes rake deploy:content
        USAGE
      )
    end

    rollout = begin
      Deploy::Rollout.new(
        server:,
        region: args[:region],
        database: ENV["PROD_DATABASE_URL"],
        only: ENV["ONLY"],
        skip: ENV["SKIP"],
        dry_run: ENV["DRY_RUN"].present?,
        checksum: ENV["CHECKSUM"].present?
      )
    rescue ArgumentError => e
      abort(e.message)
    end

    unless ENV["CONFIRM"] == "yes" || ENV["DRY_RUN"].present?
      abort(
        <<~CONFIRM
          Target #{rollout.host}:

          #{rollout.plan.join("\n")}

          Nothing is deleted: the server disk also holds files it downloaded
          itself, and their absence from this checkout does not remove them.
          Identical files are not transferred: rsync compares size and mtime,
          pronunciation templates are compared by SHA-256. Re-running with no
          local changes is a no-op.

          Confirm:
            CONFIRM=yes rake deploy:content

          Show the plan without transferring:
            DRY_RUN=1 rake deploy:content

          Narrow the set:
            ONLY=pronunciation CONFIRM=yes rake deploy:content
            SKIP=moe_audio,moe_audio_words CONFIRM=yes rake deploy:content

          Compare contents instead of timestamps (slower, survives mtime drift
          between identical files):
            CHECKSUM=1 CONFIRM=yes rake deploy:content
        CONFIRM
      )
    end

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    begin
      steps = rollout.call
    rescue => e
      abort("\nERROR: #{e.message}")
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    broken = steps.count { |step| step.status == :failed }
    puts(format("\n%s Done in %.0fs", broken.zero? ? "✓" : "✗", elapsed))
    abort("failed steps: #{broken}") if broken.positive?
  end
end
