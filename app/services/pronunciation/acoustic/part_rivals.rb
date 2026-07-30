# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module PartRivals
      PART_OF_DIMENSION = {tone: "tone", initial: "initial", medial: "medial", rime: "final"}.freeze

      module_function

      def keys_by_part(key)
        syllable, tone = Syllables.parse_key(key)
        return {} if syllable.nil?

        mine = Phonology.analyze(syllable)
        grouped = Hash.new { |hash, part| hash[part] = [] }

        Syllables.confusion_set(syllable, tone).each do |rival_key|
          other, = Syllables.parse_key(rival_key)
          next if other.nil?

          part = PART_OF_DIMENSION[dimension_between(mine, other, syllable)]
          grouped[part] << rival_key if part
        end

        grouped
      end

      def dimension_between(mine, other, syllable)
        return :tone if other == syllable

        theirs = Phonology.analyze(other)
        return :initial if theirs[:initial] != mine[:initial] && theirs[:final] == mine[:final]
        return :medial if theirs[:medial] != mine[:medial] && theirs[:initial] == mine[:initial]
        return :rime if theirs[:final] != mine[:final] && theirs[:initial] == mine[:initial]

        nil
      end
    end
  end
end
