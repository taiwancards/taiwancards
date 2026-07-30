# frozen_string_literal: true

module Textbook
  class RawParser
    RAW_DIR = AppData.path("textbook_raw")
    KEPT_ATTRIBUTES = %w[colspan rowspan].freeze
    DROPPED_TAGS = %w[svg script style img a audio video].freeze
    UI_TEXTS = ["Ready to practice the words?", "Go to Vocabulary List"].freeze

    def initialize(raw_dir: RAW_DIR)
      @raw_dir = Pathname(raw_dir)
    end

    def each_lesson
      return enum_for(:each_lesson) unless block_given?

      @raw_dir.glob("book*.json").sort.each do |path|
        raw = JSON.parse(path.read)
        raw["lessons"].each do |lesson|
          yield(parse_lesson(raw["book"], lesson))
        end
      end
    end

    private

    def parse_lesson(book, lesson)
      require "nokolexbor"

      doc = Nokolexbor::HTML(lesson["html"])
      {
        book:,
        lesson: lesson["lesson"],
        title_en: doc.css("h1").first&.text.to_s.strip,
        title_zh: huayu_title(doc),
        summary_html: sanitized_summary(doc),
        vocabulary: vocabulary(lesson["data"])
      }
    end

    def huayu_title(doc)
      candidate = doc.css("h1 ~ p, h1 + div, header p").find { |node| node.text.match?(/\p{Han}/) }
      candidate ||= doc.css("p, div").find { |node| node.text.match?(/\p{Han}/) && node.text.strip.length < 30 }
      candidate&.text&.gsub(/\s+([！？。])/, "\\1")&.strip
    end

    def sanitized_summary(doc)
      summary = doc.css("main main").first
      return if summary.nil?

      summary.css(DROPPED_TAGS.join(", ")).each(&:remove)
      summary.css("button").each { |node| node.replace("<span>#{node.inner_html}</span>") }
      summary.css("*").each do |node|
        UI_TEXTS.each { |text| node.remove if node.text.strip == text }
        node.attributes.each_key do |name|
          node.remove_attribute(name) unless KEPT_ATTRIBUTES.include?(name)
        end
      end

      summary.inner_html.gsub(/<!--.*?-->/m, "").strip
    end

    def vocabulary(data_json)
      nodes = Devalue.parse(JSON.parse(data_json))
      node = nodes.find { |n| n.is_a?(Hash) && n.key?("vocabulary") }
      return [] if node.nil?

      node["vocabulary"].filter_map do |entry|
        card = entry["card"]
        next if card.nil? || card["traditional"].blank?

        {
          "name" => card["name"],
          "traditional" => card["traditional"],
          "pinyin" => card["pinyin"],
          "meaning" => card["meaning"],
          "category" => card["category"],
          "audio" => card["audio"],
          "single_character" => card["is_single_character"]
        }
      end
    end
  end
end
