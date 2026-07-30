# frozen_string_literal: true

module Huayu
  class CharacterSupplementer
    HAN = /\p{Han}/
    SOURCE = "corpus"

    def initialize(io: $stdout)
      @io = io
    end

    def call
      known = Lexeme.where(kind: :character).pluck(:text).to_set
      missing, rejected = split(*characters_in_use, known)

      adopt_existing_without_set
      base = next_index
      missing.each_with_index do |text, offset|
        Lexeme.create!(
          kind: :character,
          text: text,
          sources: [SOURCE],
          data: {"moe_index" => base + offset, "char_set" => "補遺"}
        )
      end

      @io.puts(
        "characters supplemented: #{missing.length}#{missing.any? ? " (#{missing.join})" : ""}"
      )
      if rejected.any?
        @io.puts(
          "rejected as simplified: #{rejected.length} (#{rejected.join}) — corpus leakage"
        )
      end

      missing.length
    end

    private

    def characters_in_use
      trusted = Set.new
      raw = Set.new
      Lexeme
        .where(kind: %i[word collocation sentence])
        .select(:id, :text, :kind)
        .find_each(batch_size: 5_000) do |lexeme|
          (lexeme.sentence? ? raw : trusted).merge(lexeme.text.scan(HAN))
        end

      [trusted.to_a, raw.to_a]
    end

    def split(trusted, raw, known)
      simplified = Huayu::SimpToTrad.table
      missing = []
      rejected = []

      trusted.each do |char|
        canonical = canonical_form(char)
        missing << canonical if canonical && !known.include?(canonical)
      end

      raw.each do |char|
        canonical = canonical_form(char)
        next if canonical.nil? || known.include?(canonical) || missing.include?(canonical)

        (simplified.key?(canonical) ? rejected : missing) << canonical
      end

      [missing.uniq.sort, rejected.uniq.sort]
    end

    def canonical_form(char)
      canonical = char.unicode_normalize(:nfkc)
      canonical.match?(HAN) ? canonical : nil
    end

    def adopt_existing_without_set
      Lexeme
        .where(kind: :character)
        .where("NOT (data ? 'char_set')")
        .find_each do |lexeme|
          lexeme.data = lexeme.data.merge("char_set" => "補遺")
          lexeme.save!
        end
    end

    def next_index
      current = Lexeme
        .where(kind: :character)
        .maximum(Arel.sql("(data->>'moe_index')::int"))
      [current.to_i, 0].max + 1
    end
  end
end
