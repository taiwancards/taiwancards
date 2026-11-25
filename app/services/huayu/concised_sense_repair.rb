# frozen_string_literal: true

module Huayu
  class ConcisedSenseRepair
    SYNONYMS = JsonData.new("huayu/concised_synonyms.json", default: {})
    BATCH = 1_000

    Result = Data.define(:definitions, :chips, :synonyms, :misfiled, :rejected) do
      def changed? = to_h.values.any?(&:positive?)

      def to_s
        "concised senses: #{definitions} definitions cleaned, #{chips} chips trimmed, " \
          "#{synonyms} synonym chips, #{misfiled} misfiled and #{rejected} rejected examples removed"
      end
    end

    def initialize(io: nil)
      @io = io
    end

    def drift?
      definitions.any? || marked_chips.any? || synonym_examples.any? || misfiled.any? || rejected.any?
    end

    def call(dry_run: false)
      plan = {
        definitions: definitions,
        chips: chip_plan,
        synonyms: synonym_examples,
        misfiled: misfiled,
        rejected: rejected
      }
      report(plan)
      return result(plan) if dry_run

      ActiveRecord::Base.transaction do
        Bulk.patch(target: "lexeme_senses", columns: {"gloss_zh" => "text"}, rows: plan[:definitions])
        Bulk.patch(target: "sense_examples", columns: {"text" => "text"}, rows: plan[:chips][:trimmed])
        doomed = plan[:chips][:dropped] + plan[:synonyms] + plan[:misfiled] + plan[:rejected]
        doomed.uniq.each_slice(BATCH) { |slice| SenseExample.where(id: slice).delete_all }
      end

      result(plan)
    end

    private

    def result(plan)
      Result.new(
        definitions: plan[:definitions].size,
        chips: plan[:chips][:trimmed].size + plan[:chips][:dropped].size,
        synonyms: plan[:synonyms].size,
        misfiled: plan[:misfiled].size,
        rejected: plan[:rejected].size
      )
    end

    def definitions
      @definitions ||= begin
        marked = LexemeSense
          .where("gloss_zh ~ ? OR gloss_zh LIKE ?", ConcisedMarkup::NUMBERING_SQL, ConcisedMarkup::SYNONYMS_SQL)
          .pluck(:id, :lexeme_id, :gloss_zh)
        taken = LexemeSense.where(lexeme_id: marked.map(&:second)).pluck(:lexeme_id, :gloss_zh).to_set

        marked.filter_map do |id, lexeme_id, gloss|
          cleaned = ConcisedMarkup.definition(gloss)
          next if cleaned.nil? || cleaned == gloss || taken.include?([lexeme_id, cleaned])

          taken << [lexeme_id, cleaned]
          [id, cleaned]
        end
      end
    end

    def marked_chips
      @marked_chips ||= SenseExample
        .where("text LIKE ?", ConcisedMarkup::SYNONYMS_SQL)
        .pluck(:id, :lexeme_sense_id, :text)
    end

    def chip_plan
      taken = SenseExample
        .where(lexeme_sense_id: marked_chips.map(&:second))
        .where
        .not(id: marked_chips.map(&:first))
        .pluck(:lexeme_sense_id, :text)
        .to_set
      plan = {trimmed: [], dropped: []}

      marked_chips.each do |id, sense_id, text|
        cleaned = ConcisedMarkup.chip(text)
        if cleaned.empty? || taken.include?([sense_id, cleaned]) || synonym?(sense_id, cleaned)
          plan[:dropped] << id
        else
          taken << [sense_id, cleaned]
          plan[:trimmed] << [id, cleaned]
        end
      end

      plan
    end

    def synonym?(sense_id, text)
      headwords[sense_id].then { |word| word && SYNONYMS.value.fetch(word, []).include?(text) }
    end

    def headwords
      @headwords ||= LexemeSense.joins(:lexeme).where(id: marked_chips.map(&:second)).pluck(:id, "lexemes.text").to_h
    end

    def synonym_examples
      @synonym_examples ||= begin
        listed = SYNONYMS.value
        candidates = SenseExample
          .joins(lexeme_sense: :lexeme)
          .where(
            "sense_examples.text LIKE ? OR lexemes.text IN (?)",
            "%#{ConcisedMarkup::LIST}%",
            listed.keys.presence || [""]
          )
          .pluck(:id, :kind, :text, "lexemes.text")

        candidates.filter_map do |id, kind, text, word|
          if ConcisedMarkup.synonym_list?(text, kind) ||
              (kind == "collocation" && listed.fetch(word, []).include?(text))
            id
          end
        end
      end
    end

    def misfiled
      @misfiled ||= SenseExample
        .sentence
        .joins(lexeme_sense: :lexeme)
        .where("position(lexemes.text in sense_examples.text) = 0")
        .pluck(:id)
    end

    def rejected
      @rejected ||= garbled.each_slice(BATCH).flat_map do |slice|
        SenseExample.sentence.where(text: slice).pluck(:id)
      end
    end

    def garbled
      SentenceRejectStore.read.filter_map { |entry| entry.text if SentenceRejectStore.unconditional?(entry.reason) }
    end

    def report(plan)
      return if @io.nil?

      @io.puts(format("definitions cleaned      : %6d", plan[:definitions].size))
      @io.puts(format("chips trimmed            : %6d", plan[:chips][:trimmed].size))
      @io.puts(format("chips dropped as repeats : %6d", plan[:chips][:dropped].size))
      @io.puts(format("synonym chips removed    : %6d", plan[:synonyms].size))
      @io.puts(format("misfiled examples removed: %6d", plan[:misfiled].size))
      @io.puts(format("rejected examples removed: %6d", plan[:rejected].size))
    end
  end
end
