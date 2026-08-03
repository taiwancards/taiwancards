# frozen_string_literal: true

namespace(:deploy) do
  SYNC_STEPS = [
    {name: "content_sources", task: "huayu:import_sources", paths: %w[content_sources.json]},
    {name: "taiwan_everyday", task: "huayu:import_everyday", paths: %w[huayu/taiwan_everyday.json]},
    {name: "grammar", task: "huayu:import_grammar", paths: %w[huayu/grammar_lessons.json]},
    {name: "voiced_sentences", task: "huayu:mark_voiced", media_paths: %w[listening/manifest.json]},
    {name: "common_words", task: "huayu:import_common_words", paths: %w[huayu/common_words.json]},
    {
      name: "difficulty",
      task: "huayu:compute_difficulty",
      paths: %w[huayu/taiwan_everyday.json huayu/moe_idioms.json]
    },
    {name: "ru_glosses", task: "huayu:enrich_ru", paths: %w[huayu/ru_glosses.json]},
    {name: "gloss_overrides", task: "huayu:enrich_gloss_overrides", paths: %w[huayu/gloss_overrides.json]},
    {name: "sense_meanings", task: "huayu:fill_sense_meanings", paths: %w[huayu/sense_glosses.jsonl]},
    {
      name: "collocation_meanings",
      task: "huayu:fill_collocation_meanings",
      paths: %w[huayu/collocation_glosses.jsonl]
    },
    {
      name: "sentence_meanings",
      task: "huayu:fill_sentence_meanings",
      paths: %w[huayu/sentence_glosses.jsonl]
    },
    {name: "chengyu", task: "huayu:import_chengyu", paths: %w[huayu/moe_idioms.json huayu/chengyu.json]},
    {name: "parts_of_speech", task: "huayu:import_pos", paths: %w[huayu/parts_of_speech.json]},
    {name: "thesaurus", task: "huayu:import_thesaurus", paths: %w[huayu/thesaurus.json]},
    {
      name: "liangci",
      task: "huayu:import_liangci",
      paths: %w[huayu/measure_words.json huayu/classifier_pairs.json]
    }
  ].freeze

  ALWAYS_STEPS = {
    "flag_restricted" => -> {
      flagger = Huayu::RestrictedFlagger.new
      next :skipped unless flagger.drift?

      flagger.call
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

  desc("Import committed data sources that changed since the last boot (idempotent, no-op when unchanged)")
  task(sync: :environment) do
    started = Time.current
    ran = []
    skipped = []
    failed = []

    # Importers rescore whole tables; the web request budget does not apply to them.
    ActiveRecord::Base.connection.execute("SET statement_timeout = '15min'")
    ActiveRecord::Base.connection.execute("SET lock_timeout = '1min'")

    SYNC_STEPS.each do |step|
      sources = step[:paths].to_a.map { |relative| AppData.path(relative) } +
        step[:media_paths].to_a.map { |relative| AppData.media_path(relative) }
      next skipped << "#{step[:name]} (absent)" if sources.none?(&:exist?)

      guard = Deploy::SyncGuard.new(step[:name], sources)
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
