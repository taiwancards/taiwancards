# frozen_string_literal: true

module Huayu
  class PhoneticSeries
    PATH = AppData.path("huayu/phonetic_series.json")
    RELIABLE = 0.75
    LIMIT = 24

    Series = Data.define(:component, :members, :group, :rhyme, :rime, :regularity, :payoff, :size) do
      def reliable? = regularity >= RELIABLE

      def diverged? = reliable? && payoff < RELIABLE

      def percent = (payoff * 100).round
    end

    class << self
      def all = table

      def for_component(component) = by_component[component.to_s]

      def containing(char) = by_member[char.to_s]

      def available? = table.any?

      def size = table.length

      def reset!
        @table = nil
        @by_component = nil
        @by_member = nil
      end

      private

      def table
        @table ||= load.map { |row| build(row) }.freeze
      end

      def by_component
        @by_component ||= table.index_by(&:component).freeze
      end

      def by_member
        @by_member ||= table
          .each_with_object({}) { |series, memo| series.members.each { |member| memo[member] ||= series } }
          .freeze
      end

      def build(row)
        Series.new(
          component: row["component"],
          members: Array(row["members"]).first(LIMIT).freeze,
          group: row["group"],
          rhyme: row["rhyme"],
          rime: row["rime"],
          regularity: row["regularity"].to_f,
          payoff: row["payoff"].to_f,
          size: row["size"].to_i
        )
      end

      def load
        PATH.exist? ? JSON.parse(PATH.read) : []
      rescue JSON::ParserError
        []
      end
    end
  end
end
