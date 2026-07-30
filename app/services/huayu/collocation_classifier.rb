# frozen_string_literal: true

module Huayu
  class CollocationClassifier
    Decision = Data.define(:lexeme, :verdict, :reason, :confidence)

    MIN_LENGTH = 2

    def initialize(dictionary_path: nil, io: $stdout)
      @dictionary_path = dictionary_path || Rails.root.join("dict_and_corpora/corpora/concised.json")
      @revised_path = Rails.root.join("dict_and_corpora/corpora/moedict/dict-revised.json")
      @io = io
    end

    def call(dry_run: true)
      load_headwords
      load_own_words

      decisions = Lexeme
        .where(kind: :word)
        .where("length(text) >= ?", MIN_LENGTH)
        .find_each
        .map { |lexeme| classify(lexeme) }

      report(decisions)
      apply(decisions) unless dry_run
      decisions
    end

    private

    def load_headwords
      @headwords = Set.new

      if File.exist?(@dictionary_path)
        JSON.parse(File.read(@dictionary_path)).each { |entry| @headwords << entry["word"] }
      end

      return unless File.exist?(@revised_path)

      JSON.parse(File.read(@revised_path)).each do |entry|
        title = entry["title"]
        @headwords << title if title
      end
    end

    def load_own_words
      @known = Lexeme.where(kind: %i[word character]).pluck(:text).to_set
    end

    def classify(lexeme)
      if headword?(lexeme)
        return Decision.new(lexeme:, verdict: :word, reason: "MOE dictionary headword", confidence: :high)
      end

      if abbreviation?(lexeme)
        return Decision.new(
          lexeme:,
          verdict: :collocation,
          reason: "abbreviated collocation",
          confidence: :high
        )
      end

      parts = decompose(lexeme.text)
      if parts.length >= 2
        return Decision.new(
          lexeme:,
          verdict: :collocation,
          reason: "splits into standalone words: #{parts.join(" + ")}",
          confidence: :medium
        )
      end

      Decision.new(
        lexeme:,
        verdict: :word,
        reason: "does not split and is not tagged otherwise",
        confidence: :medium
      )
    end

    def headword?(lexeme)
      @headwords.include?(lexeme.text)
    end

    def abbreviation?(lexeme)
      lexeme.data["full"].present? || lexeme.data["origin"].to_s == "abbreviation"
    end

    def decompose(text)
      chars = text.chars
      best = split_into_words(chars, whole: text)
      return [] if best.nil?

      best.count { |part| part.length >= 2 } >= 2 ? best : []
    end

    def split_into_words(chars, whole:)
      length = chars.length
      table = Array.new(length + 1)
      table[0] = []

      (1..length).each do |stop|
        (0...stop).each do |start|
          next if table[start].nil?

          piece = chars[start, stop - start].join
          next if piece == whole
          next unless @known.include?(piece)

          candidate = table[start] + [piece]
          table[stop] = candidate if table[stop].nil? || candidate.length < table[stop].length
        end
      end

      table[length]
    end

    def report(decisions)
      by_verdict = decisions.group_by(&:verdict)
      @io.puts(format("words examined      : %6d", decisions.size))
      @io.puts(format("stay words      : %6d", by_verdict[:word].to_a.size))
      @io.puts(format("become collocations   : %6d", by_verdict[:collocation].to_a.size))

      @io.puts("\nby reason:")
      decisions.group_by(&:reason).sort_by { |_, list| -list.size }.each do |reason, list|
        @io.puts(format("  %-46s %6d", reason.truncate(44), list.size))
      end

      sample = by_verdict[:collocation].to_a.first(15)
      return if sample.empty?

      @io.puts("\nsample future collocations:")
      sample.each { |d| @io.puts("  #{d.lexeme.text}  — #{d.reason}") }
    end

    def apply(decisions)
      moved = decisions.select { |d| d.verdict == :collocation }
      moved.each_slice(500) do |slice|
        ActiveRecord::Base.transaction do
          slice.each do |decision|
            decision.lexeme.update_columns(
              kind: Lexeme.kinds[:collocation],
              data: decision.lexeme.data.merge(
                "classified_as" => "collocation",
                "classification_reason" => decision.reason,
                "classification_confidence" => decision.confidence.to_s
              )
            )
          end
        end
      end

      TextAnalyzer.reset_vocabulary!
      @io.puts("\nmoved to collocations: #{moved.size}")
    end
  end
end
