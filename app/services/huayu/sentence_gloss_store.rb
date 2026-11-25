# frozen_string_literal: true

module Huayu
  class SentenceGlossStore < JsonlStore
    PATH = AppData.path("huayu/sentence_glosses.jsonl")

    Entry = Data.define(:text, :en, :ru, :vi, :de, :ind, :ja)

    def self.put(text, en:, ru:, vi: nil, de: nil, ind: nil, ja: nil)
      entries = index
      if [en, ru, vi, de, ind, ja].all?(&:blank?)
        entries.delete(text)
      else
        entries[text] = Entry.new(
          text:,
          en: en.presence,
          ru: ru.presence,
          vi: vi.presence,
          de: de.presence,
          ind: ind.presence,
          ja: ja.presence
        )
      end

      write(entries.values)
    end

    def self.serialize(entry) = JSON.generate(entry.to_h.compact)
    private_class_method :serialize
  end
end
