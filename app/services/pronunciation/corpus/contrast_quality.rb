# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class ContrastQuality
      PATH = "contrast_quality.json"
      PROBES = 8
      MIN_PROBES = 6

      SERIES = {
        "retroflex" => %w[zh ch sh r],
        "dental" => %w[z c s],
        "alveolo_palatal" => %w[j q x]
      }.freeze

      def initialize(store: TemplateStore.instance, io: $stdout)
        @store = store
        @io = io
      end

      def call
        wanted = candidates
        @io&.puts("Contrast quality over #{wanted.length} minimal pairs")
        measured = FanOut.map(wanted, io: @io) { |chunk| measure(chunk) }.flatten(1).compact

        {
          "generated_at" => Time.current.utc.iso8601,
          "method" => "held-out native citation tokens of each member, scored against both templates",
          "pairs" => measured.sort_by { |row| [row["family"], -row["accuracy"]] }
        }
      end

      def write!
        payload = call
        File.write(File.join(@store.root, PATH), JSON.pretty_generate(payload))
        @io&.puts("  measured #{payload["pairs"].length} pairs")
        payload
      end

      def candidates
        keys = Tokens.available.select { |key| @store.template(key) }
        found = {}

        keys.each do |key|
          partners(key).each do |family, partner, nucleus|
            next unless @store.template(partner)

            pair = [key, partner].sort
            found[[family, pair]] ||= {"family" => family, "keys" => pair, "nucleus" => nucleus}.compact
          end
        end

        found.values
      end

      private

      def partners(key)
        parsed = Acoustic::Syllables.parse_key(key)
        return [] if parsed.nil?

        syllable, tone = parsed
        st = Acoustic::Syllables.structure(syllable)
        aspiration(st, tone) + sibilant(st, tone) + coda(st, tone)
      end

      def aspiration(st, tone)
        other = Acoustic::Phonology::ASPIRATION_PAIRS[st[:initial]]
        other ? [["aspiration", "#{other}#{st[:final]}#{tone}", nil]] : []
      end

      def sibilant(st, tone)
        series = st[:sibilant].to_s
        index = SERIES[series]&.index(st[:initial])
        return [] if index.nil?

        SERIES.filter_map do |name, list|
          next if name == series || list[index].nil?

          ["sibilant", "#{list[index]}#{st[:final]}#{tone}", nil]
        end
      end

      def coda(st, tone)
        return [] unless st[:coda] == "n"

        ["coda", "#{st[:initial]}#{st[:medial]}#{st[:nucleus]}ng#{tone}", st[:nucleus]].then { |row| [row] }
      end

      def measure(pairs)
        analyzer = Acoustic::Analyzer.new(@store)
        held = HeldOut.new(store: @store)

        pairs.filter_map do |pair|
          first, second = pair["keys"]
          wins, seen = decide(analyzer, held, first, second)
          more, also = decide(analyzer, held, second, first)
          total = seen + also
          next if total < MIN_PROBES

          pair.merge("accuracy" => ((wins + more).to_f / total * 100).round(1), "n" => total)
        end
      end

      def decide(analyzer, held, key, partner)
        rows = held.citations(key)
        rival = @store.template(partner)
        return [0, 0] if rival.nil?

        wins = 0
        seen = 0

        rows.first(PROBES).each do |features|
          own = held.template(key, held.without(rows, features))
          mine = held.overall(analyzer, features, own)
          theirs = held.overall(analyzer, features, rival)
          next if mine.nil? || theirs.nil?

          seen += 1
          wins += 1 if mine > theirs
        end

        [wins, seen]
      end
    end
  end
end
