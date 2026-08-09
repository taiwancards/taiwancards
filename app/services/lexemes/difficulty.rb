# frozen_string_literal: true

module Lexemes
  class Difficulty
    SCALE = 1000
    MEAN_WEIGHT = 0.6
    MAX_WEIGHT = 0.4
    GRADE_WEIGHT = 0.35
    CORPUS_WEIGHT = 0.35
    LENGTH_PENALTY = 12
    MAX_GRADE = 7
    UNKNOWN = 0.85

    SCORE_MIN = 1.0
    SCORE_MAX = 999.0

    def call
      char_scores = character_scores
      @corpus = corpus_percentiles
      rows = []
      patches = []

      Lexeme
        .where(kind: %i[character word collocation])
        .order(:id)
        .pluck(:id, :text, :data)
        .each do |id, text, data|
          raw = raw_for(text, data, char_scores)
          next if raw.nil?

          rows << [id, raw, data["freq_rank"]&.to_i, data["moe_index"]&.to_i, text]

          rounded = (raw.clamp(0.0, 1.0) * SCALE).round
          attested = @corpus.key?(text)
          next if data["difficulty"] == rounded && data["corpus_attested"] == attested

          patches << [id, {"difficulty" => rounded, "corpus_attested" => attested}]
        end

      drills = []
      Lexeme
        .where(kind: :phrase)
        .where("lexemes.data ->> 'drill' IS NOT NULL")
        .order(:id)
        .pluck(:id, :text, :data)
        .each do |id, text, data|
          raw = raw_for(text, data, char_scores)
          next if raw.nil?

          drills << [id, raw, nil, nil, text]
          rounded = (raw.clamp(0.0, 1.0) * SCALE).round
          next if data["difficulty"] == rounded

          patches << [id, {"difficulty" => rounded}]
        end

      updated = Bulk.patch(
        target: "lexemes",
        columns: {"patch" => "jsonb"},
        rows: patches,
        set: "data = lexemes.data || bulk_patch.patch"
      )

      assign_scores(rank_dictionary(rows))
      assign_scores(rank_sentences)
      assign_scores(drills.sort_by { |id, raw, _rank, _moe, text| [raw, text, id] })
      updated
    end

    private

    def character_scores
      ranks = {}
      grades = {}
      Lexeme
        .where(kind: :character)
        .pluck(:text, Arel.sql("(data->>'freq_rank')::int"), Arel.sql("(data->>'tbcl_grade')::int"))
        .each do |text, rank, grade|
          ranks[text] = rank if rank
          grades[text] = grade if grade
        end

      top = ranks.values.max.to_f
      scores = {}
      (ranks.keys | grades.keys).each do |text|
        by_rank = ranks[text] ? (ranks[text] / top) : nil
        by_grade = grades[text] ? ((grades[text] - 1).to_f / (MAX_GRADE - 1)) : nil
        scores[text] = blend(by_rank, by_grade)
      end

      scores
    end

    def blend(by_rank, by_grade)
      return by_rank if by_grade.nil?
      return by_grade if by_rank.nil?

      (by_rank * (1 - GRADE_WEIGHT)) + (by_grade * GRADE_WEIGHT)
    end

    def raw_for(text, data, char_scores)
      chars = text.chars.select { |c| c.match?(/\p{Han}/) }
      return nil if chars.empty?

      values = chars.map { |c| char_scores[c] || UNKNOWN }
      mean = values.sum / values.size
      worst = values.max
      base = (mean * MEAN_WEIGHT) + (worst * MAX_WEIGHT)
      base += (chars.size - 1) * LENGTH_PENALTY / SCALE.to_f
      own_corpus(text, own_grade(data, base))
    end

    def own_corpus(text, base)
      place = @corpus[text]
      return base if place.nil?

      (base * (1 - CORPUS_WEIGHT)) + (place * CORPUS_WEIGHT)
    end

    def corpus_percentiles
      frequency = Huayu::WordFrequency.instance
      texts = Lexeme.where(kind: %i[word collocation]).pluck(:text).uniq
      return {} if texts.empty?

      attested = texts.select { |text| frequency.adjusted(text).positive? }
      return {} if attested.empty?

      ordered = attested.sort_by { |text| [-frequency.adjusted(text), text] }
      span = [ordered.length - 1, 1].max
      ordered.each_with_index.to_h { |text, index| [text, index.to_f / span] }
    end

    def own_grade(data, base)
      grade = data["tbcl_grade"].presence&.to_i
      return base if grade.nil?

      by_grade = (grade - 1).to_f / (MAX_GRADE - 1)
      (base * (1 - GRADE_WEIGHT)) + (by_grade * GRADE_WEIGHT)
    end

    def rank_dictionary(rows)
      rows.sort_by do |id, raw, rank, moe, text|
        [raw, rank || Float::INFINITY, moe || Float::INFINITY, text, id]
      end
    end

    def rank_sentences
      Lexeme
        .where(kind: :sentence)
        .pluck(:id, Arel.sql("(data->>'difficulty')::float"), :text)
        .map { |id, raw, text| [id, raw || 0.0, nil, nil, text] }
        .sort_by { |id, raw, _rank, _moe, text| [raw, text, id] }
    end

    def assign_scores(ordered)
      return if ordered.empty?

      span = [ordered.length - 1, 1].max
      step = (SCORE_MAX - SCORE_MIN) / span

      rows = ordered.each_with_index.map { |(id, _raw), position| [id, SCORE_MIN + (position * step)] }
      Bulk.patch(target: "lexemes", columns: {"score" => "float8"}, rows: rows)
    end
  end
end
