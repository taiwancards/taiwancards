# frozen_string_literal: true

module Huayu
  class CharacterTiers
    COMMON = TWFilter::TIERS.fetch(:common)
    SECONDARY = TWFilter::TIERS.fetch(:secondary)
    RARE = TWFilter::TIERS.fetch(:rare)

    NAMES = {COMMON => "常用", SECONDARY => "次常用", RARE => "罕用"}.freeze

    extend MemoizedInstance

    class << self
      delegate :tier, :text_tier, :listed?, :name, :size, :chars_in, :exceptions, to: :instance
    end

    def tier(char) = table[char]

    def text_tier(text) = TWFilter::Checks::Script.tier_of(text)

    def listed?(char) = table.key?(char)

    def name(tier) = NAMES[tier]

    def size(tier) = table.count { |_, value| value == tier }

    def chars_in(tier) = table.filter_map { |char, value| char if value == tier }

    def exceptions = TWFilter::Tables.rows("moe_exception.txt")

    private

    def table = TWFilter::Checks::Script.tiers
  end
end
