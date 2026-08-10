# frozen_string_literal: true

module Huayu
  class GlossCollisions
    DEFINITIONS = AppData.path("dictionaries/makemeahanzi/dictionary.txt")
    MAPPING = AppData.path("dictionaries/simp_to_trad.txt")

    class << self
      def tainted
        @tainted ||= new.call
      end

      def tainted?(text)
        tainted.key?(text)
      end

      def reset!
        @tainted = nil
      end
    end

    def initialize(definitions: DEFINITIONS, mapping: MAPPING)
      @definitions = Pathname(definitions)
      @mapping = Pathname(mapping)
    end

    def call
      return {} unless @definitions.exist? && @mapping.exist?

      glosses = load_glosses

      groups.each_with_object({}) do |members, memo|
        members.each do |text|
          own = glosses[text]
          next if own.blank?
          next unless members.any? { |other| other != text && glosses[other] == own }

          memo[text] = own
        end
      end
    end

    private

    def load_glosses
      @definitions.each_line.with_object({}) do |line, memo|
        row = JSON.parse(line)
        memo[row["character"]] = row["definition"].to_s.strip
      rescue JSON::ParserError
        next
      end
    end

    def groups
      @mapping.each_line.filter_map do |line|
        next if line.start_with?("#")

        simplified, rest = line.strip.split(/\s+/, 2)
        next if simplified.blank? || rest.blank? || simplified.length != 1

        members = rest.split(/\s+/)
        members = [simplified, *members] if Traditional.char?(simplified)
        members = members.uniq
        next if members.length < 2

        members
      end
    end
  end
end
