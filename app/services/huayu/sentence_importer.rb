# frozen_string_literal: true

module Huayu
  class SentenceImporter
    BATCH = 5_000

    def initialize(root: nil, io: $stdout, limit: nil)
      @root = Pathname(root || AppData.path("corpora/sentences"))
      @io = io
      @limit = limit
      @analyzer = TextAnalyzer.new
      @difficulty = SentenceDifficulty.new
      @gate = TextGate.instance
      @predicate = Predicate.new
      @log = RejectionLog.new("sentences")
    end

    def call
      @seen = Lexeme.where(kind: :sentence).pluck(:text, :id).to_h
      stats = Hash.new(0)

      sources.each do |source, path|
        texts = JSON.parse(File.read(path))
        texts = texts.first(@limit) if @limit
        import(texts, source, stats)
        report(source, stats)
      end

      @log.report(@io)
      @io.puts(format("sentences total: %d", Lexeme.where(kind: :sentence).count))
      stats
    end

    private

    def report(source, stats)
      unless source.publishable?
        @io.puts(
          format(
            "  %-16s measured %7d · vocabulary %6d · gate %6d  (no sentence stored)",
            source.slug,
            stats["#{source.slug}_measured"],
            stats["#{source.slug}_terms"],
            stats["#{source.slug}_gate"]
          )
        )
        return
      end

      @io.puts(
        format(
          "  %-16s kept %7d · shared %5d · gate %6d · junk %5d · fragment %5d · parse %5d",
          source.slug,
          stats["#{source.slug}_new"],
          stats["#{source.slug}_shared"],
          stats["#{source.slug}_gate"],
          stats["#{source.slug}_junk"],
          stats["#{source.slug}_fragment"],
          stats["#{source.slug}_parse"]
        )
      )
    end

    def sources
      return [] unless @root.exist?

      ContentSource.ordered.filter_map do |source|
        path = @root.join("#{source.slug}.json")
        next unless path.exist?

        if source.publishable? && !source.carries_content?
          @io.puts("  #{source.slug}: disabled, skipped")
          next
        end

        [source, path]
      end
    end

    def import(texts, source, stats)
      return measure(texts, source, stats) unless source.publishable?

      texts.each_slice(BATCH) do |slice|
        prepared = prepare(slice, source, stats)
        write(prepared, source, stats)
      end
    end

    def measure(texts, source, stats)
      tally = Hash.new(0)

      texts.each_slice(BATCH) do |slice|
        judge(gate(slice, source, stats), source, stats).each do |row|
          stats["#{source.slug}_measured"] += 1
          row[:data]["segments"].each { |unit| tally[unit] += 1 if vocabulary.include?(unit) }
        end
      end

      store_samples(source, tally, stats)
    end

    def store_samples(source, tally, stats)
      RegisterSample.where(content_source: source).delete_all
      stats["#{source.slug}_terms"] = tally.size
      return if tally.empty?

      now = Time.current
      tally.each_slice(5_000) do |chunk|
        RegisterSample.insert_all(
          chunk.map { |text, n| {content_source_id: source.id, text: text, n: n, created_at: now, updated_at: now} },
          unique_by: %i[content_source_id text]
        )
      end
    end

    def vocabulary
      @vocabulary ||= Lexeme.where(kind: %i[word collocation]).pluck(:text).to_set
    end

    def gate(slice, source, stats)
      slice.filter_map do |raw|
        text = normalize(raw)
        next if text.blank?

        verdict = @gate.call(text)
        unless verdict.ok
          stats["#{source.slug}_gate"] += 1
          @log.record(source.slug, text, verdict)
          next
        end

        [text, verdict.tier]
      end
    end

    def judge(gated, source, stats)
      formal = FormalSentences::REGISTERS.include?(source.register)
      official = source.register == "official"
      judged = ParallelMap.call(gated, warmup: method(:warm)) do |text, tier|
        analyze(text, tier, formal: formal, official: official)
      end

      judged.compact.filter_map do |row|
        reason = row[:reject]
        next row unless reason

        stats["#{source.slug}_#{reason}"] += 1
        @log.record(source.slug, row[:text], TextGate::Verdict.new(ok: false, tier: nil, reason:, offender: nil))
        nil
      end
    end

    def prepare(slice, source, stats)
      gated = gate(slice, source, stats)
      shared = gated.select { |text, _| @seen.key?(text) }
      shared.each { |text, _| attach(@seen[text], source, stats) }

      judge(gated.reject { |text, _| @seen.key?(text) }, source, stats)
    end

    def warm
      WordFrequency.instance
      BigramFrequency.instance
      @analyzer.segment("暖機")
    end

    def analyze(text, tier, formal: false, official: false)
      tokens = @analyzer.segment(text)
      return nil if tokens.empty?

      return {text: text, reject: :junk} if JunkSentence.rejects?(text, words: tokens)
      if formal && @predicate.missing?(text, words: tokens, official: official)
        return {text: text, reject: :fragment}
      end

      {
        kind: Lexeme.kinds[:sentence],
        text: text,
        tier: tier,
        public_id: SecureRandom.uuid_v7,
        readings: {},
        meanings: {},
        sources: [],
        restricted: false,
        data: {
          "difficulty" => @difficulty.call(text, tokens: tokens),
          "length" => text.scan(/\p{Han}/).length,
          "taiwan" => TaiwanTopic.score(text),
          "segments" => tokens
        }
      }
    end

    def write(rows, source, stats)
      return if rows.empty?

      now = Time.current
      payload = rows.map { |row| row.merge(created_at: now, updated_at: now) }

      result = Lexeme.insert_all(
        payload,
        unique_by: %i[kind text],
        returning: %i[id text]
      )

      inserted = result.rows.map { |id, text| [text, id] }
      stats["#{source.slug}_new"] += inserted.length
      stats["#{source.slug}_parse"] += rows.length - inserted.length
      inserted.each { |text, id| @seen[text] = id }

      return if inserted.empty?

      LexemeContentSource.insert_all(
        inserted.map { |_, id| {lexeme_id: id, content_source_id: source.id, created_at: now} },
        unique_by: %i[lexeme_id content_source_id]
      )
    end

    COMPAT = /[\u{2E80}-\u{2FDF}\u{F900}-\u{FAFF}]/

    def normalize(text)
      text = text
        .to_s
        .strip
        .gsub(/[[:space:]]+/, "")
        .gsub(COMPAT) { |char| char.unicode_normalize(:nfkc) }

      return SentenceText.trim(text) unless SentenceBrackets.hollow?(text)
      return "" if SentenceBrackets.beheaded?(text)

      SentenceBrackets.clean(text)
    end

    def attach(lexeme_id, source, stats)
      LexemeContentSource.insert_all(
        [{lexeme_id: lexeme_id, content_source_id: source.id, created_at: Time.current}],
        unique_by: %i[lexeme_id content_source_id]
      )
      stats["#{source.slug}_shared"] += 1
    rescue ActiveRecord::RecordNotUnique
      nil
    end
  end
end
