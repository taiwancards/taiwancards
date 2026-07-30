# frozen_string_literal: true

module Huayu
  class SentenceText
    OPENING = "「『（《〈【〔([{".chars.to_set
    ORPHAN = /\A[\p{P}\p{S}]+/

    class << self
      def trim(text)
        text.to_s.sub(ORPHAN) { |run| run.chars.drop_while { |char| !OPENING.include?(char) }.join }
      end
    end
  end
end
