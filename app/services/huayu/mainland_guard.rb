# frozen_string_literal: true

module Huayu
  class MainlandGuard
    HEADED = %w[兒子 兒女 兒孫 兒媳 兒童 兒歌 兒戲 兒時 兒科 兒麻 兒福 兒少].freeze

    TAILED = %w[
      女兒
      嬰兒
      幼兒
      胎兒
      孤兒
      棄兒
      育兒
      托兒
      健兒
      男兒
      孩兒
      寵兒
      少兒
      生兒
      小兒
      產兒
      侄兒
      姪兒
      乾兒
      義兒
      遺兒
      孤兒
      嬰兒
      病兒
      患兒
      育兒
      那兒
      這兒
      哪兒
      味兒
      頭兒
      當兒
    ]
      .freeze

    class << self
      def instance = @instance ||= new

      def reset! = @instance = nil

      delegate :offender, :marker?, to: :instance
    end

    def initialize
      @markers = load_markers
      @headed = HEADED.to_set
      @tailed = TAILED.to_set
    end

    def offender(text)
      value = text.to_s
      hit = @markers.find { |marker| value.include?(marker) }
      return hit if hit

      erhua(value)
    end

    def marker?(text) = !offender(text).nil?

    private

    def erhua(value)
      position = 0
      while (position = value.index("兒", position))
        pair_after = value[position, 2]
        pair_before = position.positive? ? value[position - 1, 2] : nil

        unless @headed.include?(pair_after) || @tailed.include?(pair_before) || value == "兒"
          return pair_before || "兒"
        end

        position += 1
      end

      nil
    end

    def load_markers
      if ActiveRecord::Base.connection.data_source_exists?("mainland_markers")
        rows = MainlandMarker.where(active: true).pluck(:word)
        return rows.to_set if rows.any?
      end

      path = AppData.path("huayu/mainland_markers.json")
      return Set.new unless path.exist?

      JSON.parse(path.read).keys.to_set
    rescue ActiveRecord::ActiveRecordError
      Set.new
    end
  end
end
