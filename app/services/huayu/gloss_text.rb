# frozen_string_literal: true

module Huayu
  module GlossText
    TWIN = /(\p{Han}+)\|\p{Han}+/
    READING = /(?<=\p{Han})[[:blank:]]*\[[A-Za-z][A-Za-z[:blank:]]*\d[A-Za-z0-9[:blank:]]*\]/
    CLASSIFIER = /\bCL:([^;]+)/
    PLACE_REFERENCE = /\Asee \p{Han}+[縣市區鎮鄉旗州省盟]\z/

    module_function

    def normalize(text, locale: "en")
      body = text.to_s.strip
      return body if body.empty?

      body = body.gsub(TWIN) { Regexp.last_match(1) }
      body = body.gsub(READING, "")
      body = body.gsub(CLASSIFIER) { measure_words(Regexp.last_match(1), locale) }
      without_place_references(TraditionalOnly.normalize(body))
    end

    def without_place_references(body)
      senses = body.split("; ")
      kept = senses.grep_v(PLACE_REFERENCE)
      kept.empty? ? body : kept.join("; ")
    end

    def measure_words(list, locale)
      forms = list.split(/[,，]/).map(&:strip).compact_blank.join(", ")

      "#{label(locale)} #{forms}"
    end

    def label(locale)
      language = I18n.locale_available?(locale.to_s) ? locale.to_s : "en"
      I18n.t("glosses.measure_word", locale: language)
    end
  end
end
