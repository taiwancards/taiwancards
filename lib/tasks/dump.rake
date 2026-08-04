# frozen_string_literal: true

namespace(:content) do
  DUMP_PATH = -> { ENV["DUMP"].presence || Rails.root.join("tmp/content.dump").to_s }

  def content_tables = Deploy::ContentTables::ALL

  desc("Dump locally built content (no user data). Usage: rake content:dump")
  task(dump: :environment) do
    path = DUMP_PATH.call
    config = ActiveRecord::Base.connection_db_config.configuration_hash

    args = ["--format=custom", "--no-owner", "--no-privileges", "--data-only"]
    content_tables.each { |table| args << "--table=#{table}" }
    args += ["--file=#{path}"]
    args << config[:database]

    env = {}
    env["PGHOST"] = config[:host] if config[:host]
    env["PGPORT"] = config[:port].to_s if config[:port]
    env["PGUSER"] = config[:username] if config[:username]
    env["PGPASSWORD"] = config[:password] if config[:password]

    puts("Dumping #{content_tables.length} content tables…")
    ok = system(env, "pg_dump", *args)
    abort("pg_dump failed") unless ok

    size = File.size(path)
    puts(format("Done: %s (%.1f MB)", path, size / 1024.0 / 1024))
    Rake::Task["content:manifest"].invoke
  end

  HEAVY_INDEXES = %w[
    index_lexemes_on_text
    index_lexemes_on_search_text
    index_lexemes_on_search_tokens
    index_lexemes_on_sentence_segments
    index_lexemes_on_sources
  ].freeze

  def drop_heavy_indexes
    connection = ActiveRecord::Base.connection
    saved = []

    HEAVY_INDEXES.each do |name|
      definition = connection.select_value(
        ActiveRecord::Base.sanitize_sql_array(["SELECT indexdef FROM pg_indexes WHERE indexname = ?", name])
      )
      next if definition.blank?

      saved << definition
      connection.execute("DROP INDEX IF EXISTS #{connection.quote_table_name(name)}")
    end

    puts("Indexes dropped for the restore: #{saved.length}") if saved.any?
    saved
  end

  def restore_indexes(definitions)
    return if definitions.blank?

    puts("Rebuilding indexes (#{definitions.length})…")
    definitions.each_with_index do |definition, index|
      print(format("  [%d/%d] ", index + 1, definitions.length))
      started = Time.current
      ActiveRecord::Base.connection.execute(definition)
      puts(format("%.0fs", Time.current - started))
    end
  end

  desc("Show what a dump would contain")
  task(manifest: :environment) do
    puts("\nIn the dump:")
    content_tables.each do |table|
      count = ActiveRecord::Base.connection.select_value("SELECT count(*) FROM #{table}")
      puts(format("  %-24s %9d", table, count))
    end
    puts("\nNOT in the dump (server keeps its own): #{Deploy::ContentTables::USER_TABLES.join(", ")}")
  end

  desc("Restore a dump into the current database. Usage: CONFIRM=yes rake content:restore")
  task(restore: :environment) do
    path = DUMP_PATH.call
    abort("#{path} is missing") unless File.exist?(path)

    unless ENV["CONFIRM"] == "yes"
      abort(<<~USAGE)
        Restore content from #{path}.

        Existing content is removed and replaced. User accounts are kept, but
        their cards and reviews are deleted together with the lexemes they
        reference. The task stops and warns if such rows exist.

        Run:
          CONFIRM=yes rake content:restore
      USAGE
    end

    config = ActiveRecord::Base.connection_db_config.configuration_hash
    env = {}
    env["PGHOST"] = config[:host] if config[:host]
    env["PGPORT"] = config[:port].to_s if config[:port]
    env["PGUSER"] = config[:username] if config[:username]
    env["PGPASSWORD"] = config[:password] if config[:password]

    dependent = {
      "cards" => LexemeMemory.count,
      "reviews" => LexemeReview.count,
      "pronunciation attempts" => (PronunciationAttempt.count if defined?(PronunciationAttempt)).to_i
    }.select { |_, n| n.positive? }

    if dependent.any? && ENV["FORCE"] != "yes"
      abort(<<~WARN)
        The restore deletes user data referencing lexemes:
        #{dependent.map { |name, n| "  #{name}: #{n}" }.join("\n")}

        TRUNCATE … CASCADE removes dependent rows as well. If the progress is
        genuinely not needed:

          DUMP=#{path} CONFIRM=yes FORCE=yes bundle exec rake content:restore
      WARN
    end

    puts("Truncating content tables…")
    ActiveRecord::Base.connection.execute(
      "TRUNCATE #{content_tables.join(", ")} RESTART IDENTITY CASCADE"
    )

    rebuilt = drop_heavy_indexes

    puts("Restoring tables in dependency order…")
    content_tables.each_with_index do |table, index|
      args = [
        "--no-owner", "--no-privileges", "--data-only",
        "--table=#{table}",
        "--dbname=#{config[:database]}", path
      ]
      print(format("  [%2d/%2d] %-24s ", index + 1, content_tables.length, table))
      ok = system(env, "pg_restore", *args, out: File::NULL)
      abort("\nfailed to restore #{table}") unless ok

      count = ActiveRecord::Base.connection.select_value("SELECT count(*) FROM #{table}")
      puts(format("%9d", count))
    end

    restore_indexes(rebuilt)

    puts("Done.")
    Rake::Task["huayu:census"].invoke
  end
end
