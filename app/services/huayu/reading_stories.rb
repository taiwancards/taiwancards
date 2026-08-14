# frozen_string_literal: true

module Huayu
  class ReadingStories
    PATH = AppData.path("huayu/reading_stories.json")
    SOURCE = "stories"
    CATEGORIES = %w[everyday practical fable poetry].freeze

    def initialize(path: PATH)
      @path = Pathname(path)
    end

    def call
      return {error: "missing #{@path}"} unless @path.exist?

      counts = {written: 0, unchanged: 0}
      texts.each { |text| counts[apply(text, save: true)] += 1 }
      counts[:dropped] = prune
      counts[:texts] = texts.size
      counts
    end

    def drift? = texts.any? { |text| apply(text, save: false) == :written }

    private

    def texts
      @texts ||= JSON.parse(@path.exist? ? @path.read : "{}").fetch("texts", []).select do |text|
        CATEGORIES.include?(text["category"]) && Array(text["lines"]).any?
      end
    end

    def prune
      kept = texts.map { |text| text["slug"] }
      stale = ReadingText.where(source: SOURCE).where.not("body_data ->> 'slug' = ANY (ARRAY[?])", kept)
      stale.destroy_all.size
    end

    def attributes(text)
      lines = Array(text["lines"])
      {
        kind: :story,
        author: text["author"],
        level_tag: text["level_tag"],
        restricted: true,
        body: lines.map { |line| line["zh"] }.join("\n"),
        body_data: {
          "slug" => text["slug"],
          "category" => text["category"],
          "attribution" => text["attribution"],
          "translations" => {
            "en" => lines.map { |line| line["en"] },
            "ru" => lines.map { |line| line["ru"] }
          }
        }.compact
      }
    end

    def apply(text, save:)
      reading_text = ReadingText.find_or_initialize_by(source: SOURCE, title: text["title"])
      reading_text.assign_attributes(attributes(text))
      return :unchanged unless reading_text.changed?

      reading_text.save! if save
      :written
    end
  end
end
