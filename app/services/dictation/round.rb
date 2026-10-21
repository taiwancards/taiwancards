# frozen_string_literal: true

module Dictation
  class Round
    SIZE = 10
    LEVELS = (1..7).to_a.freeze
    HAN_ONLY = /\A[\p{Han}\p{P}\s]+\z/

    Item = Data.define(:clip, :url, :size, :translation)

    def self.level(requested, user)
      chosen = Integer(requested, exception: false)
      return chosen if LEVELS.include?(chosen)

      user&.level_grade.to_i.clamp(LEVELS.first, LEVELS.last)
    end

    def initialize(level:, locale:, random: Random.new)
      @level = level
      @locale = locale
      @random = random
    end

    def items
      pool.sample(SIZE, random: @random).map do |row|
        Item.new(
          clip: row.clip,
          url: Huayu::ListeningClips.clip_url(row.clip),
          size: row.text.scan(Huayu::TextReading::HAN).size,
          translation: row.translation(@locale)
        )
      end
    end

    private

    def pool
      Huayu::ListeningClips.all.select { |row| row.level == @level && row.text.match?(HAN_ONLY) }
    end
  end
end
