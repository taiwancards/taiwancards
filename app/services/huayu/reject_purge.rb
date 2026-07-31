# frozen_string_literal: true

module Huayu
  class RejectPurge
    STORES = [SentenceRejectStore, CollocationRejectStore].freeze

    def initialize(io: $stdout)
      @io = io
    end

    def call(dry_run: false)
      STORES.index_with { |store| purge(store, dry_run:) }.transform_keys { |store| store::KIND }
    end

    private

    def purge(store, dry_run:)
      entries = store.read
      return report_empty(store) if entries.empty?

      found = Lexeme.where(kind: store::KIND, text: entries.map(&:text)).pluck(:id, :text)
      studied = LexemeMemory.where(lexeme_id: found.map(&:first)).distinct.pluck(:lexeme_id).to_set
      removable = found.reject { |id, _text| studied.include?(id) }

      report(store, entries, found, removable, studied)
      return {listed: entries.size, found: found.size, removed: 0, studied: studied.size} if dry_run

      removable.map(&:first).each_slice(200) { |slice| Lexeme.where(id: slice).destroy_all }

      {listed: entries.size, found: found.size, removed: removable.size, studied: studied.size}
    end

    def report_empty(store)
      @io.puts(format("%s reject store is empty", store::KIND))
      {listed: 0, found: 0, removed: 0, studied: 0}
    end

    def report(store, entries, found, removable, studied)
      @io.puts(format("rejected %ss listed %d, present in the corpus %d", store::KIND, entries.size, found.size))
      entries.group_by(&:reason).transform_values(&:size).sort_by { |_, count| -count }.each do |reason, count|
        @io.puts(format("    %-12s %5d", reason, count))
      end

      @io.puts(format("  to remove %d", removable.size))
      return if studied.empty?

      @io.puts(format("  kept, someone is studying them: %d", studied.size))
    end
  end
end
