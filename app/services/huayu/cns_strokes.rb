# frozen_string_literal: true

module Huayu
  class CnsStrokes
    DATA = JsonData.new("huayu/cns_strokes.json")
    ATTRIBUTION = "數位發展部，CNS11643中文標準交換碼全字庫網站"
    TYPES = {"1" => :heng, "2" => :shu, "3" => :pie, "4" => :dian, "5" => :zhe}.freeze

    class << self
      def count(char) = entry(char)&.first

      def sequence(char) = entry(char)&.at(1)

      def strokes(char) = sequence(char).to_s.chars.map { |code| TYPES[code] }.compact

      def known?(char) = table.key?(char)

      def diverges?(char, count)
        official = count(char)
        official.present? && count.present? && official != count
      end

      def available? = table.any?

      def size = table.size

      def reset! = DATA.reset!

      private

      def entry(char) = table[char.to_s]

      def table = DATA.value
    end
  end
end
