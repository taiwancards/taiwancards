# frozen_string_literal: true

module Huayu
  class CharacterTiers
    COMMON = 0
    SECONDARY = 1
    RARE = 2

    NAMES = {COMMON => "常用", SECONDARY => "次常用", RARE => "罕用"}.freeze

    FILES = {
      COMMON => "huayu/moe4808.json",
      SECONDARY => "huayu/moe_next6343.json",
      RARE => "huayu/moe_rare.json"
    }.freeze

    EXCEPTION_FILE = "huayu/moe_exception.json"

    class << self
      def instance = @instance ||= new

      def reset! = @instance = nil

      delegate :tier, :text_tier, :listed?, :name, :size, :chars_in, to: :instance
    end

    def initialize
      @tiers = {}

      FILES.each do |tier, file|
        JSON.parse(AppData.path(file).read).each { |char| @tiers[char] ||= tier }
      end

      path = AppData.path(EXCEPTION_FILE)
      @exceptions = path.exist? ? JSON.parse(path.read) : []
      @exceptions.each { |char| @tiers[char] ||= COMMON }

      @tiers.freeze
    end

    def tier(char) = @tiers[char]

    def text_tier(text)
      level = COMMON

      text.to_s.each_char do |char|
        next unless char.match?(TextGate::HAN)

        char_tier = @tiers[char]
        return nil if char_tier.nil?

        level = char_tier if char_tier > level
      end

      level
    end

    def listed?(char) = @tiers.key?(char)

    def name(tier) = NAMES[tier]

    def size(tier) = @tiers.count { |_, value| value == tier }

    def chars_in(tier) = @tiers.filter_map { |char, value| char if value == tier }

    def exceptions = @exceptions
  end
end
