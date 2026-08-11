# frozen_string_literal: true

module MockExam
  class Paper
    COUNT = 10
    STEPS = 4000
    MINUTES = {"Novice1" => 8, "Novice2" => 8, "A1" => 9, "A2" => 10, "B1" => 12}.freeze

    Slot = Data.define(:number, :format, :question)

    Group = Data.define(:block, :slots) do
      def format = block.format
    end

    Sheet = Data.define(:level, :seed, :minutes, :groups) do
      def slots = groups.flat_map(&:slots)

      def count = slots.size

      def choices = Bank.choices(level)

      def formats = groups.map(&:format).uniq
    end

    class << self
      def levels = Bank.levels

      def build(level:, seed:, count: COUNT)
        blocks = choose(Bank.blocks(level).shuffle(random: Random.new(seed)), count)
        Sheet.new(level: level, seed: seed, minutes: MINUTES.fetch(level, 10), groups: number(blocks))
      end

      private

      def choose(blocks, count)
        found = search(blocks, count, [], Hash.new(0), [STEPS])
        (found || []).sort_by { |block| [block.position, block.id] }
      end

      def search(blocks, left, picked, used, budget)
        return picked if left.zero?
        return nil if budget.first <= 0

        taken = picked.to_set
        blocks
          .each_with_index
          .reject { |block, _index| taken.include?(block) || block.size > left }
          .sort_by { |block, index| [used[block.format], index] }
          .each do |block, _index|
            budget[0] -= 1
            used[block.format] += 1
            found = search(blocks, left - block.size, picked + [block], used, budget)
            used[block.format] -= 1
            return found if found
          end

        nil
      end

      def number(blocks)
        counter = 0
        blocks.map do |block|
          slots = block.questions.map do |question|
            counter += 1
            Slot.new(number: counter, format: block.format, question: question)
          end

          Group.new(block: block, slots: slots)
        end
      end
    end
  end
end
