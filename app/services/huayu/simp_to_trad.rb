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
      "系" => "系",
      "云" => "雲",
      "台" => "臺"
    }.freeze

    TAIWAN_VARIANTS = %w[
      僞偽
      啓啟
      嫺嫻
      嬀媯
      峯峰
      幺么
      擡抬
      潙溈
      潨潀
      爲為
      牀床
      癡痴
      着著
      竈灶
      糉粽
      繮韁
      羣群
      蔿蒍
      衆眾
      裏裡
      鉢缽
      鮎鯰
      麪麵
    ]
      .to_h(&:chars)
      .freeze

    RESPELLINGS = TAIWAN_VARIANTS.slice(*TWFilter::Tables.rows("converted_orthography.txt")).freeze

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

      def options(char)
        [OVERRIDES[char], *alternatives.fetch(char, [char])].compact.map { |form| taiwan(form) }.uniq
      end

      def taiwan(char) = TAIWAN_VARIANTS.fetch(char, char)

      def reset!
        @table = nil
        @alternatives = nil
      end

      private

      def build_table
        alternatives
          .transform_values(&:first)
          .merge(OVERRIDES)
          .transform_values { |form| taiwan(form) }
          .merge(RESPELLINGS)
      end

      def alternatives
        @alternatives ||= read_alternatives
      end

      def read_alternatives
        path = AppData.path(PATH)
        return {} unless path.exist?

        path.each_line.each_with_object({}) do |line, found|
          simplified, traditional = line.strip.split(/\s+/, 2)
          next if simplified.blank? || traditional.blank? || simplified.length != 1

          found[simplified] = traditional.split(/\s+/).freeze
        end
      end
    end

    def convert(text)
      return ["", []] if text.blank?

      simplified = TraditionalOnly.simplified(text).any? { |char| !RESPELLINGS.key?(char) }
      table = simplified ? self.class.table : RESPELLINGS
      changed = []
      converted = text
        .each_char
        .map { |char|
          replacement = table[char]
          next char if replacement.nil? || replacement == char

          changed << char
          replacement
        }
        .join

      [converted, changed.uniq]
    end
  end
end
