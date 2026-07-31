# frozen_string_literal: true

module Huayu
  class SentenceRejectPurge
    def initialize(io: $stdout)
      @io = io
    end

    def call(dry_run: false)
      entries = SentenceRejectStore.read
      return report_empty if entries.empty?

      by_text = entries.index_by(&:text)
      found = Lexeme.where(kind: :sentence, text: by_text.keys).pluck(:id, :text)
      studied = LexemeMemory.where(lexeme_id: found.map(&:first)).distinct.pluck(:lexeme_id).to_set
      removable = found.reject { |id, _text| studied.include?(id) }

      report(entries, found, removable, studied)
      return {listed: entries.size, found: found.size, removed: 0, studied: studied.size} if dry_run

      removable.map(&:first).each_slice(200) { |slice| Lexeme.where(id: slice).destroy_all }

      {listed: entries.size, found: found.size, removed: removable.size, studied: studied.size}
    end

    private

    def report_empty
      @io.puts("sentence reject store is empty")
      {listed: 0, found: 0, removed: 0, studied: 0}
    end

    def report(entries, found, removable, studied)
      by_reason = entries.group_by(&:reason).transform_values(&:size)
      @io.puts(format("rejected sentences listed %d, present in the corpus %d", entries.size, found.size))
      by_reason.sort_by { |_, count| -count }.each { |reason, count| @io.puts(format("    %-12s %5d", reason, count)) }
      @io.puts(format("  to remove %d", removable.size))
      return if studied.empty?

      @io.puts(format("  kept, someone is studying them: %d", studied.size))
    end
  end
end
