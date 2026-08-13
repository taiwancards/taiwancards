# frozen_string_literal: true

module Huayu
  module GlossText
    TWIN = /(\p{Han}+)\|\p{Han}+/
    READING = /(?<=\p{Han})[[:blank:]]*\[[A-Za-z][A-Za-z[:blank:]]*\d[A-Za-z0-9[:blank:]]*\]/
    CLASSIFIER = /\bCL:([^;]+)/
    LABELS = {"en" => "measure word:", "ru" => "счётное слово:"}.freeze

    module_function

    def normalize(text, locale: "en")
      body = text.to_s.strip
      return body if body.empty?

      body = body.gsub(TWIN) { Regexp.last_match(1) }
      body = body.gsub(READING, "")
      body = body.gsub(CLASSIFIER) { measure_words(Regexp.last_match(1), locale) }
      TraditionalOnly.normalize(body)
    end

    def measure_words(list, locale)
      forms = list.split(/[,，]/).map(&:strip).compact_blank.join(", ")

      "#{LABELS.fetch(locale, LABELS["en"])} #{forms}"
    end
  end
end
