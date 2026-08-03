# frozen_string_literal: true

module Huayu
  class VoicedSentences
    MARK = "common_voice"
    SLICE = 2_000

    Result = Data.define(:marked, :cleared, :total)

    def call
      texts = ListeningClips.all.map(&:text).uniq
      return Result.new(marked: 0, cleared: 0, total: 0) if texts.empty?

      Result.new(marked: mark(texts), cleared: clear(texts), total: texts.size)
    end

    private

    def mark(texts)
      texts.each_slice(SLICE).sum do |slice|
        Lexeme
          .where(kind: :sentence, text: slice)
          .where("NOT (data ? 'audio')")
          .update_all(["data = data || ?::jsonb", {audio: MARK}.to_json])
      end
    end

    def clear(texts)
      Lexeme
        .where(kind: :sentence)
        .where("data ->> 'audio' = ?", MARK)
        .where
        .not(text: texts)
        .update_all("data = data - 'audio'")
    end
  end
end
