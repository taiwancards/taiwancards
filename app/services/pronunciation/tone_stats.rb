# frozen_string_literal: true

module Pronunciation
  class ToneStats
    TONES = [1, 2, 3, 4, 5].freeze
    MIN_SAMPLES = 20

    def initialize(user)
      @user = user
    end

    def confusions
      counts = Hash.new(0)
      skills.each do |skill|
        next if skill.tone.zero?

        skill.tone_confusions.each { |heard, n| counts[[skill.tone, heard]] += n }
      end

      counts.sort_by { |_pair, count| -count }
    end

    def accuracy_by_tone
      totals = Hash.new(0)
      correct = Hash.new(0)
      skills.each do |skill|
        next if skill.tone.zero?

        totals[skill.tone] += skill.n
        correct[skill.tone] += skill.n_green
      end

      TONES.to_h { |tone| [tone, {total: totals[tone], correct: correct[tone]}] }
    end

    def accuracy_by_initial
      totals = Hash.new(0)
      correct = Hash.new(0)
      skills.each do |skill|
        initial = initial_of(skill.syllable)
        next if initial.blank?

        totals[initial] += skill.n
        correct[initial] += skill.n_green
      end

      totals.keys.sort.map { |initial| {initial:, total: totals[initial], correct: correct[initial]} }
    end

    def weakest_components(limit: 3)
      SyllableSkill::PARTS
        .filter_map { |part|
          rows = skills.filter_map { |s| [s.send(:"ewma_#{part}"), s.n] if s.send(:"ewma_#{part}") }
          n = rows.sum { |(_, count)| count }
          next if n < MIN_SAMPLES

          weighted = rows.sum { |(value, count)| value * count } / n
          {component: part, average: weighted.round(1), n: n}
        }
        .sort_by { |row| row[:average] }
        .first(limit)
    end

    private

    def skills
      @skills ||= SyllableSkill.where(user: @user).to_a
    end

    def initial_of(syllable)
      return nil if syllable.blank?

      Acoustic::Phonology.analyze(syllable)[:initial].presence
    rescue StandardError
      nil
    end
  end
end
