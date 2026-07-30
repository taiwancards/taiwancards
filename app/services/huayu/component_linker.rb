# frozen_string_literal: true

module Huayu
  class ComponentLinker
    def initialize(io: $stdout)
      @io = io
    end

    def call
      characters = Lexeme.where(kind: :character).pluck(:text, :id).to_h
      words = Lexeme.where(kind: %i[word collocation]).pluck(:text, :id).to_h

      linked_chars = link_characters(characters)
      linked_words = link_words(words)

      @io.puts(format("word→character links : %7d", linked_chars))
      @io.puts(format("collocation→word links: %7d", linked_words))
      {characters: linked_chars, words: linked_words}
    end

    private

    def link_characters(characters)
      total = 0

      Lexeme
        .where(kind: %i[word collocation])
        .select(:id, :text)
        .find_in_batches(batch_size: 1000) do |batch|
          rows = batch.flat_map do |lexeme|
            lexeme.text.chars.each_with_index.filter_map do |char, index|
              child_id = characters[char]
              next if child_id.nil?

              {parent_id: lexeme.id, child_id: child_id, position: index}
            end
          end

          total += insert(rows)
        end

      total
    end

    WORD_POSITION_OFFSET = 1000

    def link_words(words)
      analyzer = TextAnalyzer.new
      total = 0

      Lexeme
        .where(kind: :collocation)
        .select(:id, :text)
        .find_in_batches(batch_size: 500) do |batch|
          rows = batch.flat_map do |lexeme|
            parts = analyzer.segment(lexeme.text, excluding: lexeme.text)
            next [] if parts.length < 2

            parts.each_with_index.filter_map do |part, index|
              child_id = words[part]
              next if child_id.nil? || child_id == lexeme.id

              {parent_id: lexeme.id, child_id: child_id, position: WORD_POSITION_OFFSET + index}
            end
          end

          total += insert(rows)
        end

      total
    end

    def insert(rows)
      return 0 if rows.empty?

      unique = rows.uniq { |row| [row[:parent_id], row[:child_id], row[:position]] }
      LexemeLink.insert_all(unique, unique_by: %i[parent_id child_id position])
      unique.length
    rescue ActiveRecord::RecordNotUnique
      0
    end
  end
end
