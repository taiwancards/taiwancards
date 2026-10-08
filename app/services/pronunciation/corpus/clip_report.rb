# frozen_string_literal: true

module Pronunciation
  module Corpus
    class ClipReport
      TOTAL = "all sources"

      def initialize(source: Tokens::TAIWAN, io: nil)
        @source = source
        @io = io
      end

      def call
        keys = Tokens.available(@source)
        @io&.puts("Quality gate over #{keys.length} syllables")
        tally = FanOut
          .map(keys, io: @io) { |chunk| count(chunk) }
          .reduce({}) { |acc, part| merge(acc, part) }

        rows = tally.map { |source, counts| row(source, counts) }
        rows.sort_by { |entry| entry["source"] == TOTAL ? -1 : -entry["n"] }
      end

      private

      def count(keys)
        out = {}
        keys.each do |key|
          Tokens.each(key, @source, speakers: :all) do |row|
            [row["_source"].to_s, TOTAL].each do |bucket|
              counts = (out[bucket] ||= {"n" => 0, "kept" => 0})
              counts["n"] += 1
              reasons = ClipGate.reasons(row)
              reasons.empty? ? counts["kept"] += 1 : reasons.each { |name| counts[name] = counts.fetch(name, 0) + 1 }
            end
          end
        end

        out
      end

      def merge(acc, part)
        part.each do |source, counts|
          target = (acc[source] ||= {})
          counts.each { |name, value| target[name] = target.fetch(name, 0) + value }
        end

        acc
      end

      def row(source, counts)
        total = counts["n"].to_f
        reasons = counts
          .except("n", "kept")
          .transform_values { |value| (100.0 * value / total).round(1) }
          .sort_by { |_, share| -share }

        {
          "source" => source,
          "n" => counts["n"],
          "kept_share" => (100.0 * counts["kept"] / total).round(1),
          "reasons" => reasons
        }
      end
    end
  end
end
