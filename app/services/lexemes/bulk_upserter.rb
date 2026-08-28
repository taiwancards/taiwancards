# frozen_string_literal: true

module Lexemes
  class BulkUpserter
    COLUMNS = %w[kind text readings meanings data sources audio_url search_text tier].freeze

    Entry = Data.define(:kind, :text, :readings, :meanings, :audio_url, :data, :source) do
      def initialize(kind:, text:, readings: {}, meanings: {}, audio_url: nil, data: {}, source: nil)
        super
      end
    end

    Result = Data.define(:inserted, :updated, :unchanged)

    def call(entries)
      entries = Array(entries).reject { |entry| entry.text.blank? }
      return Result.new(inserted: 0, updated: 0, unchanged: 0) if entries.empty?

      known = load(entries)
      touched = {}.compare_by_identity

      entries.each do |entry|
        lexeme = lookup(known, entry) || register(known, entry)
        touched[lexeme] = true
        apply(lexeme, entry)
      end

      changed = touched.keys.select(&:changed?)
      changed.each { |lexeme| lexeme.run_callbacks(:save) { true } }
      inserted, updated = changed.partition(&:new_record?)

      write(inserted, updated)
      Result.new(inserted: inserted.size, updated: updated.size, unchanged: touched.size - changed.size)
    end

    private

    def load(entries)
      Lexeme
        .where(text: entries.map(&:text).uniq, kind: entries.flat_map { |entry| kinds(entry) }.uniq)
        .each_with_object({}) { |lexeme, index| (index[lexeme.text] ||= []) << lexeme }
    end

    def kinds(entry)
      entry.kind == :word ? Lexeme::DICTIONARY_KINDS : [entry.kind]
    end

    def lookup(known, entry)
      wanted = kinds(entry).map { |kind| Lexeme.kinds.fetch(kind.to_s) }
      known
        .fetch(entry.text, [])
        .select { |lexeme| wanted.include?(Lexeme.kinds.fetch(lexeme.kind)) }
        .min_by { |lexeme| Lexeme.kinds.fetch(lexeme.kind) }
    end

    def register(known, entry)
      lexeme = Lexeme.new(kind: entry.kind, text: entry.text)
      (known[entry.text] ||= []) << lexeme
      lexeme
    end

    def apply(lexeme, entry)
      lexeme.readings = lexeme.readings.merge(entry.readings.compact_blank) if entry.readings.present?
      lexeme.meanings = lexeme.meanings.merge(entry.meanings.compact_blank) if entry.meanings.present?
      lexeme.data = lexeme.data.merge(entry.data) if entry.data.present?
      lexeme.audio_url = entry.audio_url if entry.audio_url.present? && lexeme.audio_url.blank?
      lexeme.add_source(entry.source) if entry.source.present?
    end

    def write(inserted, updated)
      inserted.each_slice(1000) do |slice|
        Lexeme.insert_all!(slice.map { |lexeme| row(lexeme) }, record_timestamps: true)
      end

      updated.each_slice(1000) do |slice|
        rows = slice.map { |lexeme| row(lexeme).merge("id" => lexeme.id) }
        Lexeme.upsert_all(rows, unique_by: :id, record_timestamps: true)
      end
    end

    def row(lexeme)
      lexeme.attributes.slice(*COLUMNS)
    end
  end
end
