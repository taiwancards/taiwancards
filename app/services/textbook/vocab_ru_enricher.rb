# frozen_string_literal: true

module Textbook
  class VocabRuEnricher
    GLOSSES = AppData.path("huayu/ru_glosses.json")

    def call
      glosses = JSON.parse(GLOSSES.read)
      filled = 0
      missing = 0

      TextbookLesson.find_each do |lesson|
        vocabulary = Array(lesson.vocabulary).map do |entry|
          next entry if entry["meaning_ru"].to_s.strip.present?

          russian = glosses[entry["traditional"].to_s].to_s.strip
          if russian.present?
            filled += 1
            entry.merge("meaning_ru" => russian)
          else
            missing += 1
            entry
          end
        end

        lesson.update!(vocabulary:) if vocabulary != lesson.vocabulary
      end

      {filled:, still_missing: missing}
    end
  end
end
