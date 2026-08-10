# frozen_string_literal: true

module Huayu
  class SentenceBracketRepair
    MIN_HAN = 6
    BATCH = 200
    DANGLING = /[的之及或與暨為由作者至]\s*[，、。！？；：]/

    Result = Data.define(:examined, :cleaned, :removed, :studied) do
      def changed? = cleaned.positive? || removed.positive?

      def to_s
        "sentence brackets: #{cleaned} cleaned, #{removed} removed of #{examined}" \
          "#{studied.positive? ? " (#{studied} kept, in use)" : ""}"
      end
    end

    def initialize(io: nil)
      @io = io
    end

    def call(dry_run: false)
      rows = damaged
      return Result.new(examined: 0, cleaned: 0, removed: 0, studied: 0) if rows.empty?

      keep, drop = partition(rows)
      studied = LexemeMemory.where(lexeme_id: drop.map(&:first)).distinct.pluck(:lexeme_id).to_set
      removable = drop.reject { |id, _, _| studied.include?(id) }

      report(rows, keep, removable, studied)
      if dry_run
        return Result.new(examined: rows.size, cleaned: keep.size, removed: removable.size, studied: studied.size)
      end

      apply(keep)
      removable.map(&:first).each_slice(BATCH) { |slice| Lexeme.where(id: slice).destroy_all }

      Result.new(examined: rows.size, cleaned: keep.size, removed: removable.size, studied: studied.size)
    end

    def drift? = damaged.any?

    private

    def damaged
      @damaged ||= Lexeme
        .where(kind: :sentence)
        .where("text ~ ?", SentenceBrackets::SQL_ANY)
        .pluck(:id, :text)
        .select { |_, text| SentenceBrackets.residue?(text) }
    end

    def partition(rows)
      taken = Lexeme.where(kind: :sentence).where.not(id: rows.map(&:first)).pluck(:text).to_set
      keep = []
      drop = []

      rows.each do |id, text|
        cleaned = SentenceBrackets.clean(text)

        if SentenceBrackets.beheaded?(text) || unusable?(cleaned) || dangled?(text, cleaned)
          drop << [id, text, cleaned]
        elsif taken.include?(cleaned)
          drop << [id, text, cleaned]
        elsif cleaned != text
          taken << cleaned
          keep << [id, text, cleaned]
        end
      end

      [keep, drop]
    end

    def dangled?(text, cleaned)
      cleaned.match?(DANGLING) && !text.match?(DANGLING)
    end

    def unusable?(cleaned)
      return true if cleaned.scan(/\p{Han}/).length < MIN_HAN
      return true if SentenceBrackets.hollow?(cleaned)

      JunkSentence.rejects?(cleaned)
    end

    def apply(keep)
      analyzer = TextAnalyzer.new
      difficulty = SentenceDifficulty.new

      keep.each_slice(BATCH) do |slice|
        replacements = slice.to_h { |id, _, cleaned| [id, cleaned] }

        Lexeme.where(id: replacements.keys).each do |lexeme|
          cleaned = replacements[lexeme.id]
          next if cleaned.blank?

          tokens = analyzer.segment(cleaned)
          lexeme.text = cleaned
          lexeme.data = lexeme.data.merge(
            "length" => cleaned.scan(/\p{Han}/).length,
            "segments" => tokens,
            "difficulty" => difficulty.call(cleaned, tokens: tokens)
          )
          lexeme.save!
        end
      end
    end

    def report(rows, keep, removable, studied)
      return if @io.nil?

      @io.puts(format("sentences with bracket residue: %d", rows.size))
      @io.puts(format("  cleaned in place: %d", keep.size))
      @io.puts(format("  removed as unusable: %d", removable.size))
      @io.puts(format("  kept, someone is studying them: %d", studied.size)) if studied.any?
    end
  end
end
