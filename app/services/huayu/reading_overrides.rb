# frozen_string_literal: true

module Huayu
  class ReadingOverrides
    PATH = AppData.path("huayu/reading_overrides.json")

    Result = Data.define(:examined, :rewritten) do
      def to_s = "lexemes whose readings were set by the curated overrides: #{rewritten} of #{examined}"
    end

    def self.load(path = PATH) = JSON.parse(File.read(path))

    def self.for_kind(kind, entries = load)
      entries
        .select { |entry| entry.fetch("kinds").include?(kind.to_s) }
        .to_h { |entry| [entry.fetch("text"), entry.fetch("readings")] }
    end

    def self.arrange(override, readings)
      named = override.map { |reading| key(reading) }
      override + readings.reject { |reading| named.include?(key(reading)) }
    end

    def self.key(reading) = reading["pinyin"].to_s.delete(" ")

    def initialize(entries: self.class.load, io: $stdout)
      @entries = entries
      @io = io
    end

    def call
      stale.each { |lexeme, readings| rewrite(lexeme, readings) }
      result = Result.new(examined: matching.size, rewritten: stale.size)
      @io.puts(result.to_s)
      result
    end

    def drift? = stale.any?

    private

    def matching
      @matching ||= @entries.flat_map do |entry|
        Lexeme
          .where(text: entry.fetch("text"), kind: entry.fetch("kinds"))
          .map { |lexeme| [lexeme, entry.fetch("readings")] }
      end
    end

    def stale
      @stale ||= matching.reject do |lexeme, readings|
        lexeme.readings == readings.first && lexeme.data["readings"] == readings
      end
    end

    def rewrite(lexeme, readings)
      lexeme.update_columns(readings: readings.first, data: lexeme.data.merge("readings" => readings))
    end
  end
end
