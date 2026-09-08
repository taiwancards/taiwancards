# frozen_string_literal: true

module Huayu
  class SentenceGlossStore < JsonlStore
    PATH = AppData.path("huayu/sentence_glosses.jsonl")

    Entry = Data.define(:text, :en, :ru)

    def self.put(text, en:, ru:)
      entries = index
      if en.blank? && ru.blank?
        entries.delete(text)
      else
        entries[text] = Entry.new(text:, en: en.presence, ru: ru.presence)
      end

      write(entries.values)
    end
  end
end
