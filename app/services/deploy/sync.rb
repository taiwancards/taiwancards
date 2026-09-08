# frozen_string_literal: true

module Deploy
  class Sync
    Report = Data.define(:ran, :skipped, :failed, :elapsed) do
      def to_s
        line = "deploy:sync ran [#{ran.join(", ")}] · unchanged [#{skipped.join(", ")}] (#{elapsed}s)"
        failed.any? ? "#{line} · FAILED [#{failed.join(", ")}]" : line
      end
    end

    def initialize(scope: ENV["SYNC_SCOPE"], io: $stdout)
      @scope = scope
      @io = io
      @ran = []
      @skipped = []
      @failed = []
    end

    def content_only? = @scope == "content"

    def call
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      MaintenanceWindow.open!

      SyncSteps::STEPS.each { |step| run_step(step) }
      SyncSteps::ALWAYS.each { |name, action| run_always(name, action) }
      refresh_caches

      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(2)
      Report.new(ran: @ran, skipped: @skipped, failed: @failed, elapsed:)
    end

    private

    def run_step(step)
      sources = step.sources
      return @skipped << "#{step.name} (absent)" if sources.none?(&:exist?)

      guard = SyncGuard.new(step.name, sources + step.code_paths)
      return @skipped << step.name unless guard.stale?

      attempt(step.name) do
        timed(step.name) { Rake::Task[step.task].invoke }
        guard.remember!
        @ran << step.name
      end
    end

    def run_always(name, action)
      return @skipped << "#{name} (account)" if content_only? && SyncSteps::ACCOUNT.include?(name)

      attempt(name) { timed(name) { action.call } == :skipped ? @skipped << name : @ran << name }
    end

    def refresh_caches
      if content_only?
        @skipped << "derived_caches (content scope)" << "edge_purge (content scope)"
      elsif (@ran - SyncSteps::WARMING).any?
        attempt("derived_caches", recover: false) do
          timed("derived_caches") { DerivedCaches.refresh }
          @ran << "derived_caches"
        end

        purge_edge
      else
        @skipped << "derived_caches"
      end
    end

    def purge_edge
      return @skipped << "edge_purge (unconfigured)" unless DerivedCaches.edge_configured?

      timed("edge_purge") { DerivedCaches.purge_edge }
      @ran << "edge_purge"
    end

    def attempt(name, recover: true)
      yield
    rescue => e
      @failed << "#{name} (#{e.class})"
      warn("deploy:sync step #{name} failed: #{e.class}: #{e.message}")
      recover_connection if recover
    end

    def timed(name)
      @io.puts("deploy:sync → #{name}")
      @io.flush
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      @io.puts("deploy:sync ← #{name} (#{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(2)}s)")
      @io.flush
      result
    end

    def recover_connection
      ActiveRecord::Base.connection.verify!
      MaintenanceWindow.open!
    rescue => e
      warn("deploy:sync could not restore the database connection: #{e.class}: #{e.message}")
    end
  end
end
