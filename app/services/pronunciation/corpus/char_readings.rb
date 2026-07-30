# frozen_string_literal: true

require "json"
require "zlib"

module Pronunciation
  module Corpus
    module CharReadings
      SOURCE = "cache/cedict.txt.gz"
      LINE = /\A(\S+)\s+(\S+)\s+\[([^\]]+)\]/

      module_function

      def path = File.join(TemplateStore.instance.root, SOURCE)

      def table
        @table ||= build
      end

      def reset! = @table = nil

      def key_for(char)
        reading = table[char]
        reading && reading.tr("u:", "v").gsub(/[^a-z0-9]/, "")
      end

      def build
        counts = Hash.new { |hash, char| hash[char] = Hash.new(0) }

        Zlib::GzipReader.open(path) do |gz|
          gz.each_line do |line|
            next if line.start_with?("#")

            match = line.match(LINE)
            next if match.nil?

            traditional = match[1]
            syllables = match[3].split
            next unless traditional.length == syllables.length

            traditional.chars.each_with_index { |char, i| counts[char][syllables[i].downcase] += 1 }
          end
        end

        counts.transform_values { |readings| readings.max_by { |_, n| n }.first }
      end
    end
  end
end
