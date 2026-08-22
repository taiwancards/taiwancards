# frozen_string_literal: true

module Pronunciation
  class Phrases
    DATA = JsonData.new("huayu/pronunciation_phrases.json", default: {"phrases" => []}, watch: true)
    BEGINNER_LEVEL = 1

    class << self
      def instance = @instance ||= new

      def reset!
        DATA.reset!
        @instance = nil
      end
    end

    def available? = rows.any?

    def level_for(user)
      return BEGINNER_LEVEL if user.nil?

      [user.level_grade, BEGINNER_LEVEL].max
    end

    def ids_up_to(level)
      texts = rows.select { |row| row["level"].to_i <= level }.map { |row| row["text"] }
      return [] if texts.empty?

      by_text = lexemes.slice(*texts)
      texts.filter_map { |text| by_text[text] }
    end

    def include?(id) = lexemes.value?(id)

    def rows = DATA.value["phrases"] || []

    private

    def lexemes
      @lexemes ||= Lexeme
        .where(kind: :sentence, text: rows.map { |row| row["text"] })
        .pluck(:text, :id)
        .to_h
    end
  end
end
