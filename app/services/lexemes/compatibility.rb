# frozen_string_literal: true

module Lexemes
  class Compatibility
    EXAMPLES = 3
    THIN_SAMPLE = 5

    Pair = Data.define(:texts, :collocation, :together, :capped, :examples)
    RegisterGap = Data.define(:left, :right, :left_style, :right_style, :left_share, :right_share)
    ClassifierCheck = Data.define(:measure_word, :noun, :listed, :main, :alternatives)
    Result = Data.define(:pair, :register_gap, :classifier) do
      def any? = [pair, register_gap, classifier].any?(&:present?)
    end

    def initialize(user:)
      @user = user
    end

    def call(texts)
      texts = Array(texts).map { |text| text.to_s.strip }.reject(&:blank?).uniq
      return nil if texts.length < 2

      lexemes = resolve(texts)
      return nil if lexemes.length < 2

      Result.new(
        pair: pair_for(texts),
        register_gap: register_gap_for(lexemes),
        classifier: classifier_for(texts, lexemes)
      )
    end

    private

    def resolve(texts)
      found = Lexeme
        .where(kind: %i[character word collocation measure_word], text: texts)
        .order(:kind)
        .to_a
        .group_by(&:text)
      texts.filter_map { |text| found[text]&.first }
    end

    def pair_for(texts)
      concordance = ::Search::Concordance.new(user: @user)
      result = concordance.call(groups: texts.map { |text| [text] }, order: :easy, page: 1)

      Pair.new(
        texts: texts,
        collocation: collocation_for(texts),
        together: result.total,
        capped: result.capped,
        examples: result.rows.first(EXAMPLES)
      )
    end

    def collocation_for(texts)
      Lexeme
        .where(kind: %i[collocation word])
        .where(text: texts.join)
        .first ||
        Lexeme
          .where(kind: :collocation)
          .where(texts.map { "text LIKE ?" }.join(" AND "), *texts.map { |text| "%#{text}%" })
          .curriculum_order
          .first
    end

    def register_gap_for(lexemes)
      left, right = lexemes.first(2)
      styles = ContentSource.registers.keys
      left_mix = Array(left.data["register_mix"])
      right_mix = Array(right.data["register_mix"])
      return nil if left_mix.compact.empty? || right_mix.compact.empty?
      return nil if left.data["register_n"].to_i < THIN_SAMPLE || right.data["register_n"].to_i < THIN_SAMPLE

      left_peak = peak(left_mix)
      right_peak = peak(right_mix)
      return nil if left_peak.nil? || right_peak.nil? || left_peak == right_peak

      RegisterGap.new(
        left: left,
        right: right,
        left_style: styles[left_peak],
        right_style: styles[right_peak],
        left_share: (left_mix[left_peak].to_f * 100).round,
        right_share: (right_mix[right_peak].to_f * 100).round
      )
    end

    def peak(mix)
      best = mix.each_with_index.reject { |share, _| share.nil? }.max_by { |share, _| share.to_f }
      best&.last
    end

    def classifier_for(texts, lexemes)
      measure = Lexeme.where(kind: :measure_word, text: texts).first
      return nil if measure.nil?

      noun = lexemes.find { |lexeme| lexeme.text != measure.text && Array(lexeme.data["classifiers"]).any? }
      return nil if noun.nil?

      rows = Array(noun.data["classifiers"])
      match = rows.find { |row| row["text"] == measure.text }

      ClassifierCheck.new(
        measure_word: measure,
        noun: noun,
        listed: match.present?,
        main: match&.dig("main").present?,
        alternatives: rows.reject { |row| row["text"] == measure.text }.map { |row| row["text"] }.first(4)
      )
    end
  end
end
