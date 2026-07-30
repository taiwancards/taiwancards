# frozen_string_literal: true

module Huayu
  class Numerals
    DIGITS = %w[零 一 二 三 四 五 六 七 八 九].freeze
    FORMAL_DIGITS = %w[零 壹 貳 參 肆 伍 陸 柒 捌 玖].freeze
    SMALL_UNITS = ["", "十", "百", "千"].freeze
    FORMAL_SMALL_UNITS = ["", "拾", "佰", "仟"].freeze
    GROUP_UNITS = ["", "萬", "億", "兆"].freeze

    MAX = 10 ** 16 - 1

    LIANG = "兩"
    ZERO = "零"

    class << self
      def spell(number, formal: false, liang: true)
        number = Integer(number)
        raise ArgumentError, "out of range" if number.negative? || number > MAX
        return digits(formal)[0] if number.zero?

        groups = split_groups(number)
        out = +""
        previous_index = nil

        (groups.size - 1).downto(0) do |index|
          value = groups[index]
          next if value.zero?

          if previous_index
            skipped = previous_index - index > 1
            out << ZERO if skipped || value < 1000
          end

          out << spell_group(value, formal, liang, scaled: index.positive?) << GROUP_UNITS[index]
          previous_index = index
        end

        out
      end

      def group_names
        GROUP_UNITS
      end

      def split_groups(number)
        out = []
        while number.positive?
          out << (number % 10_000)
          number /= 10_000
        end

        out
      end

      private

      def digits(formal)
        formal ? FORMAL_DIGITS : DIGITS
      end

      def small_units(formal)
        formal ? FORMAL_SMALL_UNITS : SMALL_UNITS
      end

      def spell_group(value, formal, liang, scaled: false)
        chars = digits(formal)
        units = small_units(formal)
        return LIANG if value == 2 && liang && !formal && scaled

        out = +""
        pending_zero = false

        3.downto(0) do |position|
          digit = (value / (10 ** position)) % 10

          if digit.zero?
            pending_zero = true if out.present?
            next
          end

          out << ZERO if pending_zero
          pending_zero = false

          out <<
            if digit == 2 && liang && !formal && position >= 2
              LIANG
            else
              chars[digit]
            end
          out << units[position]
        end

        drop_leading_one(out, formal, value)
      end

      def drop_leading_one(text, formal, value)
        return text if formal
        return text unless value.between?(10, 19)

        text.delete_prefix(DIGITS[1])
      end
    end
  end
end
