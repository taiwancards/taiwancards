# frozen_string_literal: true

module Lexemes
  class Upserter
    def word(text, readings: {}, meanings: {}, audio_url: nil, pos: nil, source: nil)
      upsert(:word, text, readings:, meanings:, audio_url:, data: {"pos" => pos}.compact_blank, source:)
    end

    def phrase(text, meanings: {}, audio_url: nil, source: nil, data: {})
      upsert(:phrase, text, meanings:, audio_url:, source:, data:)
    end

    def character(text, source: nil)
      upsert(:character, text, source:)
    end

    def link(parent, children, readings: [])
      children.each_with_index do |child, index|
        link = LexemeLink.find_or_initialize_by(parent:, child:, position: index)
        reading = readings[index]
        link.reading = reading if reading.present?
        link.save! if link.new_record? || link.changed?
      end
    end

    private

    def upsert(kind, text, readings: {}, meanings: {}, audio_url: nil, data: {}, source: nil)
      lexeme = Lexeme.find_or_initialize_by(kind: Lexeme.kinds[kind], text:)
      lexeme.readings = lexeme.readings.merge(readings.compact_blank) if readings.present?
      lexeme.meanings = lexeme.meanings.merge(meanings.compact_blank) if meanings.present?
      lexeme.data = lexeme.data.merge(data) if data.present?
      lexeme.audio_url = audio_url if audio_url.present? && lexeme.audio_url.blank?
      lexeme.add_source(source) if source.present?
      lexeme.save! if lexeme.changed?
      lexeme
    end
  end
end
