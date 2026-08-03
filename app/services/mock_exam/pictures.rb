# frozen_string_literal: true

module MockExam
  class Pictures
    BANDS = {
      "novice" => {max_level: 2, count: 8, minutes: 8},
      "a" => {max_level: 4, count: 10, minutes: 10}
    }.freeze

    Question = Data.define(:number, :text, :clip, :options, :answer, :meanings) do
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
        rows = Huayu::ListeningClips.with_emoji(max_level: config[:max_level]).shuffle(random: rng)

        used_words = Set.new
        questions = []
        rows.each do |row|
          break if questions.size >= config[:count]
          next if used_words.include?(row.emoji_word)

          wrong = distractors(row, rows, rng)
          next if wrong.size < 2

          options = ([row.emoji] + wrong).shuffle(random: rng)
          used_words << row.emoji_word
          questions <<
            Question.new(
              number: questions.size + 1,
              text: row.text,
              clip: row.clip,
              options: options,
              answer: options.index(row.emoji),
              meanings: {"en" => row.en, "ru" => row.ru}
            )
        end

        Paper.new(band:, seed:, minutes: config[:minutes], questions:)
      end

      private

      def distractors(row, rows, rng)
        rows
          .select { |candidate| candidate.emoji_category == row.emoji_category && candidate.emoji != row.emoji }
          .map(&:emoji)
          .uniq
          .shuffle(random: rng)
          .first(2)
      end
    end
  end
end
