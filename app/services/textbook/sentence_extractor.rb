# frozen_string_literal: true

require "nokogiri"

module Textbook
  class SentenceExtractor
    HAN = /\p{Han}/
    LATIN = /[A-Za-z]/
    DASH = /\s*[—–]\s+/
    ENDING = /[。！？]/
    KEEP = /[\p{Han}，、。？！：；…「」『』（）0-9]/
    MIN_HAN = 3
    MAX_HAN = 42
    MAX_TRANSLATION = 220

    def call(lesson)
      english = extract(lesson.summary_html)
      russian = extract(lesson.summary_html_ru)

      english.map do |huayu, gloss_en|
        {
          "traditional" => huayu,
          "meaning_en" => gloss_en,
          "meaning_ru" => russian[huayu],
          "sentence" => huayu.match?(ENDING)
        }
      end
    end

    private

    def extract(html)
      return {} if html.blank?

      result = {}
      Nokogiri::HTML.fragment(html).css("li").each do |node|
        text = node.text.to_s.strip.gsub(/\s+/, " ")
        parts = text.split(DASH, 2)
        next unless parts.length == 2

        huayu_part, translation = parts
        translation = translation.to_s.strip
        next if huayu_part.match?(LATIN)
        next if translation.blank? || translation.match?(HAN) || translation.length > MAX_TRANSLATION

        huayu = clean_huayu(huayu_part)
        next if huayu.nil?

        result[huayu] ||= translation
      end

      result
    end

    def clean_huayu(part)
      cleaned = part.to_s.gsub(/[（(][^）)]*[）)]/, "").chars.select { |char| char.match?(KEEP) }.join
      han = cleaned.scan(HAN).size
      return nil if han < MIN_HAN || han > MAX_HAN

      cleaned
    end
  end
end
