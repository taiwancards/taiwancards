# frozen_string_literal: true

module MockExam
  class Listening
    BANDS = {
      "novice" => {max_level: 2, count: 8, minutes: 10},
      "a" => {max_level: 4, count: 10, minutes: 12},
      "b" => {max_level: 6, count: 10, minutes: 12},
      "c" => {max_level: 7, count: 10, minutes: 12}
    }.freeze

    Question = Data.define(:number, :mode, :text, :clip, :options, :answer, :meanings) do
      def translation(locale) = meanings[locale.to_s].presence || meanings["en"]

      def emoji? = mode == "emoji"
    end

    Paper = Data.define(:band, :seed, :minutes, :questions) do
      def count = questions.size
    end

    class << self
      def bands = BANDS.keys

      def build(band:, seed:)
        config = BANDS.fetch(band)
        rng = Random.new(seed)
        pool = Huayu::ListeningClips.pool(max_level: config[:max_level])
        rows = pool.shuffle(random: rng)
        emoji_pool = pool.select(&:emoji?).map(&:emoji).uniq

        used = Set.new
        questions = []
        rows.each do |row|
          break if questions.size >= config[:count]
          next if used.include?(row.text)

          question = row.emoji? ? emoji_question(row, rows, emoji_pool, rng) : text_question(row, pool, rng)
          next if question.nil?

          used << row.text
          questions << Question.new(number: questions.size + 1, **question)
        end

        Paper.new(band:, seed:, minutes: config[:minutes], questions:)
      end

      private

      def emoji_question(row, rows, emoji_pool, rng)
        same_category = rows
          .select { |candidate| candidate.emoji_category == row.emoji_category && candidate.emoji != row.emoji }
          .map(&:emoji)
          .uniq
        wrong = same_category.shuffle(random: rng).first(2)
        wrong += (emoji_pool - [row.emoji] - wrong).shuffle(random: rng).first(2 - wrong.size) if wrong.size < 2
        return nil if wrong.size < 2

        options = ([row.emoji] + wrong).shuffle(random: rng)
        {
          mode: "emoji",
          text: row.text,
          clip: row.clip,
          options: options,
          answer: options.index(row.emoji),
          meanings: {"en" => row.en, "ru" => row.ru}
        }
      end

      def text_question(row, pool, rng)
        length = row.text.length
        near = pool.select do |candidate|
          candidate.text != row.text &&
            (candidate.text.length - length).abs <= [length / 2, 4].max
        end

        wrong = near.map(&:text).uniq.shuffle(random: rng).first(2)
        return nil if wrong.size < 2

        options = ([row.text] + wrong).shuffle(random: rng)
        {
          mode: "text",
          text: row.text,
          clip: row.clip,
          options: options,
          answer: options.index(row.text),
          meanings: {"en" => row.en, "ru" => row.ru}
        }
      end
    end
  end
end
