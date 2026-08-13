# frozen_string_literal: true

module Pronunciation
  module Corpus
    class Ladder
      RUNGS = [
        {id: "tw_exact", speakers: :taiwan, syllable: :same, tone: :same},
        {id: "cn_exact", speakers: :china, syllable: :same, tone: :same},
        {id: "tw_near_tone", speakers: :taiwan, syllable: :same, tone: :other},
        {id: "tw_near_syllable", speakers: :taiwan, syllable: :near, tone: :same},
        {id: "tw_near_both", speakers: :taiwan, syllable: :near, tone: :other},
        {id: "tw_far_syllable", speakers: :taiwan, syllable: :far, tone: :same},
        {id: "tw_far_both", speakers: :taiwan, syllable: :far, tone: :other},
        {id: "cn_far_both", speakers: :china, syllable: :far, tone: :other}
      ].freeze

      PER_RUNG = 4
      SOURCES = {taiwan: Tokens::TAIWAN, china: Tokens::CHINA}.freeze

      def initialize(part: "test", store: TemplateStore.instance, io: $stdout)
        @part = part
        @store = store
        @io = io
      end

      def call
        keys = Tokens.keys(@part)
        raise "no keys in the '#{@part}' split" if keys.empty?

        @io&.puts("Ladder over #{keys.length} syllables of the '#{@part}' split")
        chunks = FanOut.map(keys, io: @io) { |chunk| measure(chunk) }

        merged = Hash.new { |hash, rung| hash[rung] = [] }
        chunks.each { |chunk| chunk.each { |rung, scores| merged[rung].concat(scores) } }

        {
          "generated_at" => Time.current.utc.iso8601,
          "split" => @part,
          "rungs" => RUNGS.filter_map { |rung| summarize(rung, merged[rung[:id]]) }
        }
      end

      private

      def measure(keys)
        analyzer = Acoustic::Analyzer.new(@store)
        verdict = Verdict.new(store: @store)
        result = Hash.new { |hash, rung| hash[rung] = [] }
        inventory = Acoustic::Syllables.all_syllables

        keys.each do |key|
          template = @store.template(key) or next
          norm = template["norm"] || TemplateStore::CITATION
          syllable, tone = Acoustic::Syllables.parse_key(key)
          next if syllable.nil?

          near = Acoustic::Phonology.neighbors(syllable, inventory)
          far = far_syllables(syllable, near, inventory, key)

          RUNGS.each do |rung|
            source = SOURCES.fetch(rung[:speakers])

            candidates(rung, syllable, tone, near, far, source).each do |candidate|
              Tokens.sample(candidate, PER_RUNG, source).each do |features|
                score = overall(analyzer, features, template, norm)
                next if score.nil?

                result[rung[:id]] << [score, verdict.level("overall", score)]
              end
            end
          end
        end

        result
      end

      def candidates(rung, syllable, tone, near, far, source)
        pool = case rung[:syllable]
        when :same
          [syllable]
        when :near
          near.first(3)
        else
          far
        end

        available = Tokens.available(source)
        pool
          .flat_map { |other|
            tones = Acoustic::Syllables.tones_for(other)
            wanted = rung[:tone] == :same ? tones.select { |t| t == tone } : tones.reject { |t| t == tone }
            wanted.first(2).map { |t| "#{other}#{t}" }
          }
          .select { |candidate| available.include?(candidate) }
          .first(3)
      end

      def far_syllables(syllable, near, inventory, key)
        excluded = near.to_set << syllable
        pool = inventory.reject { |other| excluded.include?(other) }
        return [] if pool.empty?

        offset = key.sum
        Array.new([3, pool.length].min) { |i| pool[(offset + (i * 137)) % pool.length] }
      end

      def overall(analyzer, features, template, norm)
        parts = analyzer.part_scores(analyzer.score_axes(features, template, norm))
        return nil if parts.empty?

        analyzer.weighted_overall(parts, Acoustic::Weights::BASE.slice(*parts.map { |p| p["id"] }))
      end

      def summarize(rung, rows)
        return nil if rows.length < 30

        scores = rows.map(&:first).sort
        levels = rows.map(&:last).tally
        total = rows.length.to_f

        {
          "id" => rung[:id],
          "n" => rows.length,
          "median" => scores[scores.length / 2],
          "p25" => scores[(scores.length * 0.25).floor],
          "p75" => scores[(scores.length * 0.75).floor],
          "green" => (100.0 * levels.fetch("green", 0) / total).round(1),
          "red_or_worse" => (100.0 * (levels.fetch("red", 0) + levels.fetch("dark", 0)) / total).round(1)
        }
      end
    end
  end
end
