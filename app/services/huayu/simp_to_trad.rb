# frozen_string_literal: true

module Huayu
  class SimpToTrad
    PATH = "dictionaries/simp_to_trad.txt"

    OVERRIDES = {
      "发" => "發",
      "干" => "乾",
      "后" => "後",
      "里" => "裡",
      "只" => "只",
      "面" => "麵",
      "系" => "系",
      "云" => "雲",
      "台" => "臺"
    }.freeze

    class << self
      def convert(text)
        new.convert(text)
      end

      def available?
        AppData.path(PATH).exist?
      end

      def table
        @table ||= build_table
      end

      def reset!
        @table = nil
      end

      private

      def build_table
        path = AppData.path(PATH)
        return {} unless path.exist?

        table = {}
        path.each_line do |line|
          simplified, traditional = line.strip.split(/\s+/, 2)
          next if simplified.blank? || traditional.blank? || simplified.length != 1

          table[simplified] = traditional.split(/\s+/).first
        end

        table.merge(OVERRIDES)
      end
    end

    def convert(text)
      return ["", []] if text.blank?

      table = self.class.table
      changed = []
      converted = text
        .each_char
        .map { |char|
          replacement = table[char]
          if replacement && replacement != char
            changed << char
            replacement
          else
            char
          end
        }
        .join

      [converted, changed.uniq]
    end
  end
end
