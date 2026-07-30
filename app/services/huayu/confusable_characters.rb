# frozen_string_literal: true

module Huayu
  class ConfusableCharacters
    PATH = AppData.path("huayu/confusable_characters.json")
    LIMIT = 6

    class << self
      def for(char, limit: LIMIT) = Array(table[char.to_s]).first(limit).map(&:first)

      def scored(char, limit: LIMIT) = Array(table[char.to_s]).first(limit)

      def distractors(char, count:, pool: nil)
        found = self.for(char, limit: count * 2)
        found &= pool if pool
        found.first(count)
      end

      def covers?(char) = table.key?(char.to_s)

      def available? = table.any?

      def size = table.size

      def reset! = @table = nil

      private

      def table
        @table ||= PATH.exist? ? JSON.parse(PATH.read) : {}
      rescue JSON::ParserError
        {}
      end
    end
  end
end
