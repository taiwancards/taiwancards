# frozen_string_literal: true

module MockExam
  class Reading
    BANDS = {
      "novice" => {max_level: 2, count: 10, minutes: 12},
      "a" => {max_level: 4, count: 10, minutes: 12},
      "b" => {max_level: 6, count: 10, minutes: 14},
      "c" => {max_level: 7, count: 10, minutes: 15}
    }.freeze

    POOL = 400
    BLANK = "＿＿"
    CACHE = ProcessCache.new(ttl: 12.hours, limit: 8)

    Question = Data.define(:number, :text, :cloze, :options, :answer, :meanings) do
      def translation(locale) = meanings[locale.to_s].presence || meanings["en"]
    end

    Paper = Data.define(:band, :seed, :minutes, :questions) do
      def count = questions.size
    end

    class << self
      def bands = BANDS.keys

      def build(band:, seed:)
        config = BANDS.fetch(band)
        rng = Random.new(seed)
        questions = pick_questions(config, rng)
        Paper.new(band:, seed:, minutes: config[:minutes], questions:)
      end

      private

      def pick_questions(config, rng)
        rows = candidates(config[:max_level]).shuffle(random: rng)
        pool = distractor_pool(config[:max_level])
        used_sentences = Set.new
        used_words = Set.new
        picked = []

        rows.each do |row|
          break if picked.size >= config[:count]
          next if used_sentences.include?(row[:sentence]) || used_words.include?(row[:word])

          wrong = distractors(pool, row, rng)
          next if wrong.size < 2

          options = ([row[:word]] + wrong).shuffle(random: rng)
          used_sentences << row[:sentence]
          used_words << row[:word]
          picked <<
            Question.new(
              number: picked.size + 1,
              text: row[:sentence],
              cloze: row[:sentence].gsub(row[:word], BLANK),
              options: options,
              answer: options.index(row[:word]),
              meanings: row[:meanings] || {}
            )
        end

        picked
      end

      def candidates(max_level)
        SentenceWord
          .joins("JOIN lexemes sentences ON sentences.id = sentence_words.sentence_id")
          .joins("JOIN sentence_profiles ON sentence_profiles.lexeme_id = sentences.id")
          .joins("JOIN lexemes words ON words.id = sentence_words.lexeme_id")
          .where("sentences.restricted = FALSE")
          .where("sentences.tocfl_half <= ?", max_level)
          .where("sentence_profiles.han_length BETWEEN 6 AND 30")
          .where("words.kind = ?", Lexeme.kinds[:word])
          .where("words.data ? 'tocfl_level'")
          .where("char_length(words.text) >= 2")
          .order("sentence_words.gdex DESC")
          .limit(POOL)
          .pluck(
            Arel.sql("sentences.text"),
            Arel.sql("sentences.meanings"),
            Arel.sql("words.text"),
            Arel.sql("words.level_index"),
            Arel.sql("words.data -> 'pos'")
          )
          .map do |sentence, meanings, word, level, pos|
            {sentence:, meanings:, word:, level: level.to_i, pos: Array(pos).first || pos}
          end
          .select { |row| TWFilter.keep?(row[:word], policy: TWFilter::Policy.permissive) }
      end

      def distractor_pool(max_level)
        CACHE.fetch("pool/#{max_level}") do
          Lexeme
            .where(kind: :word)
            .where("data ? 'tocfl_level'")
            .where(level_index: 1..max_level)
            .where("char_length(text) >= 2")
            .pluck(:text, :level_index, Arel.sql("data -> 'pos'"))
            .map { |text, level, pos| {text:, level: level.to_i, pos: Array(pos).first || pos} }
            .select { |row| TWFilter.keep?(row[:text], policy: TWFilter::Policy.permissive) }
        end
      end

      def distractors(pool, row, rng)
        near = pool.select do |entry|
          entry[:text] != row[:word] &&
            !row[:sentence].include?(entry[:text]) &&
            (entry[:level] - row[:level]).abs <= 1 &&
            entry[:text].length == row[:word].length &&
            (row[:pos].nil? || entry[:pos] == row[:pos])
        end

        if near.size < 2
          near = pool.select { |entry| entry[:text] != row[:word] && !row[:sentence].include?(entry[:text]) }
        end

        near.map { |entry| entry[:text] }.uniq.shuffle(random: rng).first(2)
      end
    end
  end
end
