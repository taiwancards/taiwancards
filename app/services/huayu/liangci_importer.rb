# frozen_string_literal: true

module Huayu
  class LiangciImporter
    LIST_PATH = AppData.path("huayu/measure_words.json")
    PAIRS_PATH = AppData.path("huayu/classifier_pairs.json")
    SOURCE_TAG = "liangci"
    NOUN_KINDS = %i[word character collocation].freeze
    DICTIONARY_WEIGHT = 1000
    SCORE_MIN = 1.0
    SCORE_MAX = 999.0

    def initialize
      @list = JSON.parse(File.read(LIST_PATH))
      @pairs = File.exist?(PAIRS_PATH) ? JSON.parse(File.read(PAIRS_PATH)) : {}
    end

    def call
      lexemes = @list.to_h { |row| [row["traditional"], upsert(row)] }
      nouns = attach_nouns(lexemes)
      rank(lexemes)
      {measure_words: lexemes.size, nouns:}
    end

    private

    def upsert(row)
      text = row["traditional"]
      lexeme = Lexeme.find_or_initialize_by(kind: Lexeme.kinds[:measure_word], text:)
      lexeme.readings = {"pinyin" => row["pinyin"], "zhuyin" => row["zhuyin"]}.compact_blank
      lexeme.meanings = {"en" => row["meaning_en"], "ru" => row["meaning_ru"]}.compact_blank
      lexeme.data = lexeme.data.merge(
        {
          "category" => row["category"],
          "notes" => {"en" => row["notes_en"], "ru" => row["notes_ru"]}.compact_blank.presence,
          "moe_gloss" => row["moe_gloss"].presence,
          "tocfl_pos" => row["tocfl_pos"].presence,
          "usage" => @pairs.dig(text, "usage").to_i
        }.compact
      )
      lexeme.add_source(SOURCE_TAG)
      lexeme.save! if lexeme.changed?
      lexeme
    end

    def attach_nouns(lexemes)
      known = noun_lexemes
      by_noun = Hash.new { |store, key| store[key] = [] }
      written = 0

      lexemes.each do |text, lexeme|
        rows = Array(@pairs.dig(text, "nouns")).select { |row| known.key?(row["noun"]) }
        rows.each { |row| by_noun[row["noun"]] << row.merge("classifier" => text) }
        write(lexeme, "nouns" => rows.map { |row| row["noun"] })
      end

      by_noun.each do |noun, rows|
        ordered = rows.sort_by do |row|
          [
            -weight(row),
            row["rank"] || Float::INFINITY,
            -usage(row["classifier"]),
            row["classifier"]
          ]
        end

        payload = ordered.each_with_index.map do |row, index|
          {
            "text" => row["classifier"],
            "count" => row["seen"].to_i,
            "sources" => row["sources"],
            "main" => index.zero?
          }
        end

        known.fetch(noun).each { |lexeme| write(lexeme, "classifiers" => payload) }
        written += 1
      end

      clear_stale(by_noun.keys)
      written
    end

    def weight(row)
      row["seen"].to_i + ((row["sources"] & %w[moe cedict curated]).any? ? DICTIONARY_WEIGHT : 0)
    end

    def usage(classifier)
      @pairs.dig(classifier, "usage").to_i
    end

    def noun_lexemes
      Lexeme
        .where(kind: NOUN_KINDS)
        .where(text: @pairs.values.flat_map { |row| Array(row["nouns"]).map { |pair| pair["noun"] } }.uniq)
        .group_by(&:text)
    end

    def clear_stale(current)
      Lexeme
        .where(kind: NOUN_KINDS)
        .where("data ? 'classifiers'")
        .where
        .not(text: current)
        .find_each { |lexeme| lexeme.update_column(:data, lexeme.data.except("classifiers")) }
    end

    def write(lexeme, attributes)
      merged = lexeme.data.merge(attributes)
      lexeme.update_column(:data, merged) if merged != lexeme.data
    end

    def rank(lexemes)
      ordered = lexemes.values.sort_by do |lexeme|
        [-lexeme.data["usage"].to_i, lexeme.text]
      end

      step = (SCORE_MAX - SCORE_MIN) / [ordered.length - 1, 1].max

      ordered.each_with_index do |lexeme, index|
        score = SCORE_MIN + (index * step)
        lexeme.update_column(:score, score) if lexeme.score != score
      end
    end
  end
end
