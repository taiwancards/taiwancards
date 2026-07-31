# frozen_string_literal: true

namespace(:site) do
  DEPLOYABLE_ASSETS = %w[environment tailwindcss:build].freeze

  desc("Render the public pages into site/ for the static service")
  task(build: DEPLOYABLE_ASSETS) do
    Site::Exporter.new.call
  end

  desc("Rebuild site/ only when it no longer matches the pages it is built from")
  task(refresh: DEPLOYABLE_ASSETS) do
    freshness = Site::Freshness.new
    missing = freshness.missing_env

    if missing.any?
      puts("site:refresh skipped, #{missing.join(", ")} not set")
      next
    end

    drift = freshness.drift

    if drift.empty?
      puts("site: up to date")
      next
    end

    Site::Exporter.new(io: StringIO.new).call
    puts("site: rebuilt #{drift.length} file(s), commit them\n  #{drift.join("\n  ")}")
  end

  desc("Fail when site/ no longer matches the pages it is built from")
  task(check: DEPLOYABLE_ASSETS) do
    freshness = Site::Freshness.new
    missing = freshness.missing_env

    if missing.any?
      puts("site:check skipped, #{missing.join(", ")} not set")
      next
    end

    drift = freshness.drift

    if drift.any?
      abort("site/ is #{drift.length} file(s) out of date — run `just site`:\n  #{drift.join("\n  ")}")
    end

    puts("site: up to date")
  end
end
