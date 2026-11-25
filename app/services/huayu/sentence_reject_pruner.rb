# frozen_string_literal: true

module Huayu
  class SentenceRejectPruner
    FLOOR = 3
    KEEP = 1
    HANDLED_ELSEWHERE = "off_taiwan"
    BATCH = 1_000
    LOOKUP = 5_000
    PRESENT_SQL = "coalesce(btrim(lexemes.meanings ->> '%s'), '') <> ''"

    PROTECTING = {
      LexemeMemory => %i[lexeme_id],
      LexemeReview => %i[lexeme_id],
      PronunciationAttempt => %i[lexeme_id],
      PronunciationRecording => %i[lexeme_id],
      CollectionItem => %i[lexeme_id],
      SenseExample => %i[lexeme_id],
      LexemeSense => %i[lexeme_id],
      LexemeLink => %i[parent_id child_id]
    }.freeze

    Plan = Data.define(:removable, :spared, :protected, :unconditional)
    Candidate = Data.define(:id, :languages, :unconditional)
    Tally = Struct.new(:total, :translated)

    def initialize(io: $stdout)
      @io = io
    end

    def call(dry_run: false)
      result = {
        listed: listed.size,
        found: found.size,
        protected: plan.protected.size,
        spared: plan.spared.size,
        removed: plan.removable.size
      }
      report(result, dry_run:)
      remove(plan.removable) unless dry_run
      result
    end

    def plan
      @plan ||= build_plan
    end

    private

    def listed
      @listed ||= entries.map(&:text).uniq
    end

    def entries
      @entries ||= SentenceRejectStore.read.reject { |entry| entry.reason == HANDLED_ELSEWHERE }
    end

    def unconditional_texts
      @unconditional_texts ||= entries
        .select { |entry| SentenceRejectStore.unconditional?(entry.reason) }
        .to_set(&:text)
    end

    def found
      @found ||= listed.each_slice(LOOKUP).flat_map do |texts|
        Lexeme
          .where(kind: :sentence, text: texts)
          .pluck(:id, :text, *Locales::STORED.map { |key| Arel.sql(format(PRESENT_SQL, key)) })
          .map { |id, text, *flags|
            Candidate.new(
              id:,
              languages: Locales::STORED.select.with_index { |_, index| flags[index] },
              unconditional: unconditional_texts.include?(text)
            )
          }
      end
    end

    def build_plan
      protected_ids = protected_among(found.map(&:id))
      candidates = found
        .reject { |candidate| protected_ids.include?(candidate.id) }
        .sort_by { |candidate| [candidate.unconditional ? 0 : 1, candidate.languages.empty? ? 0 : 1, candidate.id] }
      removable, spared = decide(candidates)
      Plan.new(
        removable: removable.freeze,
        spared: spared.freeze,
        protected: found.map(&:id).select { |id| protected_ids.include?(id) }.sort.freeze,
        unconditional: candidates.select(&:unconditional).map(&:id).freeze
      )
    end

    def protected_among(ids)
      ids.each_slice(LOOKUP).each_with_object(Set.new) do |slice, protected_ids|
        PROTECTING.each do |model, columns|
          columns.each { |column| protected_ids.merge(model.where(column => slice).distinct.pluck(column)) }
        end
      end
    end

    def decide(candidates)
      ids = candidates.map(&:id)
      visible = visible_among(ids)
      links = links_of(ids)
      tallies = tally(links.values.flatten.uniq)

      candidates.each_with_object([[], []]) do |candidate, (removable, spared)|
        words = links.fetch(candidate.id, [])
        if !visible.include?(candidate.id) || words.empty?
          removable << candidate.id
        elsif candidate.unconditional
          words.each { |word| release(tallies.fetch(word), candidate.languages) }
          removable << candidate.id
        elsif words.all? { |word| spareable?(tallies.fetch(word), candidate.languages) }
          words.each { |word| release(tallies.fetch(word), candidate.languages) }
          removable << candidate.id
        else
          spared << candidate.id
        end
      end
    end

    def spareable?(tally, languages)
      tally.total - 1 >= KEEP && languages.all? { |key| tally.translated.fetch(key) - 1 >= FLOOR }
    end

    def release(tally, languages)
      tally.total -= 1
      languages.each { |key| tally.translated[key] -= 1 }
    end

    def visible_sentences = Lexeme.where(kind: :sentence).visible_to(nil)

    def visible_among(ids)
      ids.each_slice(LOOKUP).each_with_object(Set.new) do |slice, visible|
        visible.merge(visible_sentences.where(id: slice).pluck(:id))
      end
    end

    def links_of(ids)
      ids.each_slice(LOOKUP).each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |slice, links|
        SentenceWord.where(sentence_id: slice).pluck(:sentence_id, :lexeme_id).each do |sentence_id, lexeme_id|
          links[sentence_id] << lexeme_id
        end
      end
    end

    def tally(words)
      counts = Locales::STORED.map { |key| Arel.sql(format("COUNT(*) FILTER (WHERE #{PRESENT_SQL})", key)) }
      words.each_slice(LOOKUP).each_with_object({}) do |slice, tallies|
        visible_sentences
          .joins("JOIN sentence_words ON sentence_words.sentence_id = lexemes.id")
          .where(sentence_words: {lexeme_id: slice})
          .group("sentence_words.lexeme_id")
          .pluck(Arel.sql("sentence_words.lexeme_id"), Arel.sql("COUNT(*)"), *counts)
          .each { |word, total, *translated| tallies[word] = Tally.new(total, Locales::STORED.zip(translated).to_h) }
      end
    end

    def remove(ids)
      ids.each_slice(BATCH) do |slice|
        Lexeme.transaction do
          SentenceProfile.where(lexeme_id: slice).delete_all
          LexemeContentSource.where(lexeme_id: slice).delete_all
          Lexeme.where(id: slice, kind: :sentence).delete_all
        end
      end
    end

    def report(result, dry_run:)
      @io.puts(
        format(
          "rejected sentences listed %d (%s left to retire_off_taiwan), present in the corpus %d",
          result[:listed],
          HANDLED_ELSEWHERE,
          result[:found]
        )
      )
      @io.puts(format("  kept, someone uses them: %d", result[:protected]))
      @io.puts(
        format(
          "  removed whatever the floor says (%s): %d",
          SentenceRejectStore::UNCONDITIONAL.join(", "),
          plan.unconditional.size
        )
      )
      @io.puts(format("  kept, last examples of a word: %d", result[:spared]))
      @io.puts(format("  %s %d", dry_run ? "to remove" : "removed", result[:removed]))
    end
  end
end
