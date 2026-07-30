# frozen_string_literal: true

module Pronunciation
  module Corpus
    module Rivals
      PART_OF_DIMENSION = {tone: "tone", initial: "initial", medial: "medial", rime: "final"}.freeze

      PER_DIMENSION = 2

      module_function

      def for(key, store:, norm: nil)
        syllable, tone = Acoustic::Syllables.parse_key(key)
        return {} if syllable.nil?

        mine = Acoustic::Phonology.analyze(syllable)
        grouped = Hash.new { |hash, dimension| hash[dimension] = [] }

        Acoustic::Syllables.confusion_set(syllable, tone).each do |rival_key|
          other, = Acoustic::Syllables.parse_key(rival_key)
          next if other.nil?

          dimension = dimension_between(mine, other, syllable)
          next if dimension.nil? || grouped[dimension].length >= PER_DIMENSION

          template = store.template(rival_key, norm) || store.template(rival_key)
          grouped[dimension] << template if template
        end

        grouped
      end

      def dimension_between(mine, other, syllable)
        return :tone if other == syllable

        theirs = Acoustic::Phonology.analyze(other)
        return :initial if theirs[:initial] != mine[:initial] && theirs[:final] == mine[:final]
        return :medial if theirs[:medial] != mine[:medial] && theirs[:initial] == mine[:initial]
        return :rime if theirs[:final] != mine[:final] && theirs[:initial] == mine[:initial]

        nil
      end
    end
  end
end
