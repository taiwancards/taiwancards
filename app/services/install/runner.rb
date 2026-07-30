# frozen_string_literal: true

module Install
  class Runner
    PHASES = ["Source files", "Schema", "Content", "Indexes and vacuum", "Census and integrity"].freeze

    def initialize(io: $stdout)
      @console = Console.new(io: io)
      @io = io
      @failed = false
    end

    def call
      @console.title("FULL LOCAL REBUILD")
      Hardware.report(@io)

      audit
      schema
      content
      compact
      census

      finish
    end

    def verify
      @console.title("CENSUS AND INTEGRITY")
      census
      finish
    end

    private

    def phase(index, title, &block)
      @console.phase(index, PHASES.length, title)
      block.call
    end

    def audit
      phase(1, PHASES[0]) do
        audit = Huayu::SourceAudit.new
        missing = audit.call
        raise "missing required sources: #{missing.join(", ")}" if missing.any?

        rows = audit.report
        %w[data corpora media].each do |group|
          set = rows.select { |row| row[:group] == group }
          @console.line(format("%-10s %d/%d", group, set.count { |row| row[:present] }, set.size))
        end

        optional = audit.optional_missing
        @console.warn("optional missing: #{optional.join(", ")}") if optional.any?
      end
    end

    def schema
      phase(2, PHASES[1]) do
        connection = ActiveRecord::Base.connection
        @console.line("tables: #{connection.tables.size}")
        @console.line("migration: #{connection.select_value("SELECT max(version) FROM schema_migrations")}")
      end
    end

    def content
      phase(3, PHASES[2]) do
        @console.note("dictionaries, corpora, links, thresholds, translations — the long one")
        @console.note("indexes are built after the load, commits run without fsync")
        Rake::Task["huayu:rebuild"].reenable
        Rake::Task["huayu:rebuild"].invoke
      end
    end

    def compact
      phase(4, PHASES[3]) do
        config = ActiveRecord::Base.connection_db_config.configuration_hash
        tables = ActiveRecord::Base.connection.select_values(
          "SELECT quote_ident(tablename) FROM pg_tables WHERE schemaname = current_schema()"
        )

        @console.step("vacuum full · #{tables.length} tables · #{Hardware.maintenance_workers} jobs") do
          run_vacuum(config, tables)
        end

        @console.step("analyze catalog") { run_analyze(config) }
        @console.step("drop derived caches") { ContentCache.clear }
        sizes
      end
    end

    def run_vacuum(config, tables)
      args = ["--full", "--analyze", "--quiet", "--jobs=#{Hardware.maintenance_workers}"]
      args += ["--host=#{config[:host] || "localhost"}", "--port=#{config[:port] || 5432}"]
      args += ["--dbname=#{config[:database]}"]
      args += tables.map { |table| "--table=#{table}" }
      raise "vacuumdb failed" unless system("vacuumdb", *args, out: File::NULL, err: File::NULL)
    end

    def run_analyze(config)
      system(
        "vacuumdb",
        "--analyze-only",
        "--quiet",
        "--host=#{config[:host] || "localhost"}",
        "--port=#{config[:port] || 5432}",
        "--dbname=#{config[:database]}",
        out: File::NULL,
        err: File::NULL
      )
    end

    def sizes
      connection = ActiveRecord::Base.connection
      rows = connection.select_rows(
        <<~SQL
          SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
          FROM pg_catalog.pg_statio_user_tables
          ORDER BY pg_total_relation_size(relid) DESC LIMIT 6
        SQL
      )

      @io.puts("")
      @console.note("largest tables")
      @console.table(rows, [28, 12])
      @console.line(
        "database: #{connection.select_value("SELECT pg_size_pretty(pg_database_size(current_database()))")}"
      )
    end

    def census
      phase(5, PHASES[4]) do
        Rake::Task["huayu:census"].reenable
        Rake::Task["huayu:census"].invoke

        @io.puts("")
        @console.note("visibility tiers")
        Lexeme.group(:tier).count.sort.each do |tier, count|
          @console.line(format("%-8s %8d", Huayu::CharacterTiers.name(tier) || tier, count))
        end

        checks = integrity
        bad = checks.reject { |_, actual, expected| actual == expected }
        if bad.empty?
          @console.ok("integrity clean")
        else
          @failed = true
          bad.each { |name, actual, _| @console.warn("#{name}: #{actual}") }
        end
      end
    end

    def integrity
      [
        ["sentences without a public id", Lexeme.where(kind: :sentence, public_id: nil).count, 0],
        ["sentences no commercial license covers", Licenses::Enforcer.uncovered.count, 0],
        ["word links hanging off a non-sentence", stray_links, 0],
        ["lexemes above the rare tier", Lexeme.where("tier > ?", Huayu::CharacterTiers::RARE).count, 0]
      ]
    end

    def stray_links
      SentenceWord.joins(:sentence).where.not(lexemes: {kind: :sentence}).count +
        SentenceWord.joins(:lexeme).where(lexemes: {kind: :sentence}).count
    end

    def finish
      @io.puts("")
      @console.rule
      if @failed
        @console.title("FINISHED WITH WARNINGS in #{@console.elapsed}")
        abort
      end

      @console.title("DONE in #{@console.elapsed}")
      @console.note("next: bin/rebuild-data-render.sh, then bin/rebuild-db-render.sh")
    end
  end
end
