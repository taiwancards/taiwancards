# frozen_string_literal: true

module Huayu
  class ChinaVocabularyPurge
    KINDS = %i[character word collocation measure_word].freeze
    LEVEL_KEYS = %w[tocfl_level tbcl_grade].freeze

    def initialize(io: $stdout)
      @io = io
    end

    def call(dry_run: false)
      curriculum, untagged = candidates.partition { |_id, _text, tagged| tagged }
      studied = LexemeMemory.where(lexeme_id: curriculum.map(&:first)).distinct.pluck(:lexeme_id).to_set
      removable = curriculum.reject { |id, _text, _tagged| studied.include?(id) }

      report(removable, studied, untagged)
      return {curriculum: curriculum.size, removed: 0, studied: studied.size, review: untagged.size} if dry_run

      removable.map(&:first).each_slice(200) { |slice| Lexeme.where(id: slice).destroy_all }
      ChinaGuard.reset!

      {curriculum: curriculum.size, removed: removable.size, studied: studied.size, review: untagged.size}
    end

    private

    def candidates
      Lexeme
        .where(kind: KINDS)
        .where
        .not("sources @> ?", [TaiwanEverydayImporter::SOURCE].to_json)
        .pluck(:id, :text, :data)
        .filter_map { |id, text, data|
          [id, text, LEVEL_KEYS.any? { |key| data[key].present? }] if ChinaGuard.marker?(text)
        }
    end

    def report(removable, studied, untagged)
      @io.puts(format("curriculum vocabulary to remove: %d", removable.size))
      removable.map { |_id, text, _tagged| text }.each_slice(12) { |slice| @io.puts("  #{slice.join(" ")}") }

      if studied.any?
        @io.puts("  kept, someone is studying them: #{Lexeme.where(id: studied).pluck(:text).join(" ")}")
      end

      return if untagged.empty?

      @io.puts(format("untagged entries left for review: %d", untagged.size))
      untagged.map { |_id, text, _tagged| text }.each_slice(12) { |slice| @io.puts("  #{slice.join(" ")}") }
    end
  end
end
