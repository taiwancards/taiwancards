# frozen_string_literal: true

module Pronunciation
  class Keeper
    PER_KEY = 6
    UNRATED_ROOM = 80
    MAX_BYTES = 512 * 1024

    def initialize(user)
      @user = user
    end

    def keep(audio:, text:, result:, expected: [], lexeme: nil, content_type: nil)
      return nil unless collecting?

      bytes = audio.to_s
      return nil if bytes.empty? || bytes.bytesize > MAX_BYTES

      rows = rows_of(result)
      return nil if rows.empty?
      return nil unless room_for?(rows)

      PronunciationRecording.create!(
        user: @user,
        lexeme: lexeme,
        text: text.to_s.presence || rows.map { |row| row["syllable"] }.join,
        syllable_keys: rows.filter_map { |row| row["key"] }.uniq,
        syllables: rows,
        expected: Array(expected),
        audio: bytes,
        content_type: content_type.presence
      )
    end

    def collecting?
      @user.present? && @user.restricted_access? && PronunciationRecording.unrated.count < UNRATED_ROOM
    end

    private

    def rows_of(result)
      Array(result["syllables"]).each_with_index.filter_map do |syllable, index|
        key = syllable["key"].presence
        next if key.nil?

        {
          "key" => key,
          "index" => index,
          "char" => syllable["char"],
          "zhuyin" => syllable["zhuyin"],
          "overall" => syllable["overall"],
          "level" => syllable["level"],
          "cells" => cells_of(syllable)
        }
      end
    end

    def cells_of(syllable)
      Hash(syllable["cells"]).transform_values { |cell| cell["score"] }.compact
    end

    def room_for?(rows)
      keys = rows.filter_map { |row| row["key"] }.uniq
      return false if keys.empty?

      seen = PronunciationRecording.where("syllable_keys && ARRAY[?]::varchar[]", keys).pluck(:syllable_keys)
      counts = seen.flatten.tally

      keys.any? { |key| counts.fetch(key, 0) < PER_KEY }
    end
  end
end
