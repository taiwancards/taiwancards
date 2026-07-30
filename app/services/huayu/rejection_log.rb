# frozen_string_literal: true

module Huayu
  class RejectionLog
    PATH = Rails.root.join("tmp/rejected")

    REASONS = %i[unlisted junk mainland no_han empty].freeze

    def initialize(name, path: nil)
      @name = name
      @path = Pathname(path || PATH.join("#{name}.tsv"))
      @counts = Hash.new(0)
      @offenders = Hash.new(0)
      @rows = []
    end

    def record(source, text, verdict)
      @counts[[source, verdict.reason]] += 1
      @offenders[verdict.offender] += 1 if verdict.offender
      @rows << [source, verdict.reason, verdict.offender, text]
    end

    def total = @rows.length

    def flush!
      return if @rows.empty?

      @path.dirname.mkpath
      @path.open("a") do |file|
        @rows.each { |row| file.puts(row.join("\t")) }
      end

      @rows.clear
    end

    def summary
      by_reason = Hash.new(0)
      @counts.each { |(_, reason), count| by_reason[reason] += count }
      by_reason
    end

    def report(io = $stdout)
      flush!
      return if @counts.empty?

      io.puts("  rejected #{@counts.values.sum}, log in #{@path.relative_path_from(Rails.root)}")
      summary.sort_by { |_, count| -count }.each do |reason, count|
        io.puts(format("    %-10s %8d", reason, count))
      end

      top = @offenders.sort_by { |_, count| -count }.first(8)
      io.puts("    frequent offenders: #{top.map { |char, count| "#{char}×#{count}" }.join(", ")}") if top.any?
    end

    def self.reset!
      FileUtils.rm_rf(PATH)
    end
  end
end
