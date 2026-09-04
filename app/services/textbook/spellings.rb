# frozen_string_literal: true

module Textbook
  module Spellings
    ALTERNATION = %r{(\S)/(\S)}

    module_function

    def of(text)
      value = text.to_s.strip
      return [] if value.blank?
      return [value] unless value.include?("/")

      match = value.match(ALTERNATION)
      return [] if match.nil?

      [match[1], match[2]].flat_map { |char| of(value.sub(match[0], char)) }.uniq
    end
  end
end
