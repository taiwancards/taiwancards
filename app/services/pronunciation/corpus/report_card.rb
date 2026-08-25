# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class ReportCard
      SERIES = ContrastQuality::SERIES

      def initialize(part: "test", speakers: :fitting, store: TemplateStore.instance, io: $stdout)
        @part = part
        @speakers = speakers
        @store = store
        @io = io
      end

      def call
        keys = Tokens.keys(@part)
        raise "no keys in the '#{@part}' split" if keys.empty?

        @io&.puts("Report over #{keys.length} syllables of the '#{@part}' split, #{@speakers} voices")
        chunks = FanOut.map(keys, io: @io) { |chunk| measure(chunk) }

        {
          "generated_at" => Time.current.utc.iso8601,
          "split" => @part,
          "speakers" => @speakers.to_s,
          "n_keys" => keys.length,
          "top1" => top1(chunks),
          "contrasts" => contrasts(chunks),
          "families" => families(chunks),
          "natives" => natives(chunks)
        }
      end

      private

      def measure(keys)
        analyzer = Acoustic::Analyzer.new(@store)
        verdict = Verdict.new(store: @store)
        result = {
          top1: [0, 0],
          pairs: Hash.new { |hash, dimension| hash[dimension] = {self: [], rival: []} },
          overall: [],
          levels: Hash.new(0),
          families: Hash.new { |hash, label| hash[label] = [0, 0] }
        }

        keys.each do |key|
          next unless @store.template(key)

          Tokens.each(key, speakers: @speakers) do |features|
            norm = norm_of(features)
            template = @store.template(key, norm) || @store.template(key) or next
            rivals = rivals_for(key, norm)
            own = syllable_score(analyzer, features, template, norm)
            next if own.nil?

            result[:overall] << own[:overall]
            result[:levels][verdict.level("overall", own[:overall])] += 1

            best = analyzer.rank_candidates(features, key, norm).first
            result[:top1][1] += 1
            result[:top1][0] += 1 if best.nil? || best["key"] == key

            family_partners(key).each do |family, label, partner|
              rival = @store.template(partner, norm) || @store.template(partner)
              next if rival.nil?

              other = syllable_score(analyzer, features, rival, norm)
              next if other.nil?

              [family, "#{family}:#{label}"].each do |bucket|
                result[:families][bucket][1] += 1
                result[:families][bucket][0] += 1 if own[:overall] > other[:overall]
              end
            end

            rivals.each do |dimension, list|
              cell = Rivals::PART_OF_DIMENSION[dimension]
              list.each do |rival|
                other = syllable_score(analyzer, features, rival, norm)
                next if other.nil?

                result[:pairs][cell][:self] << own[:parts][cell]
                result[:pairs][cell][:rival] << other[:parts][cell]
              end
            end
          end
        end

        result[:pairs] = result[:pairs].to_h
        result[:levels] = result[:levels].to_h
        result[:families] = result[:families].to_h
        result
      end

      def family_partners(key)
        @partners ||= {}
        @partners[key] ||= build_partners(key)
      end

      def build_partners(key)
        parsed = Acoustic::Syllables.parse_key(key)
        return [] if parsed.nil?

        syllable, tone = parsed
        st = Acoustic::Syllables.structure(syllable)

        tone_partners(syllable, tone) + aspiration_partners(st, tone) + sibilant_partners(st, tone) +
          coda_partners(st, tone)
      end

      def tone_partners(syllable, tone)
        Acoustic::Syllables
          .tones_for(syllable)
          .reject { |other| other == tone }
          .map { |other| ["tone", "#{tone}v#{other}", Acoustic::Syllables.key_for(syllable, other)] }
      end

      def aspiration_partners(st, tone)
        other = Acoustic::Phonology::ASPIRATION_PAIRS[st[:initial]]
        return [] if other.nil?

        [["aspiration", [st[:initial], other].sort.join("/"), "#{other}#{st[:final]}#{tone}"]]
      end

      def sibilant_partners(st, tone)
        series = st[:sibilant].to_s
        index = SERIES[series]&.index(st[:initial])
        return [] if index.nil?

        SERIES.filter_map do |name, list|
          next if name == series || list[index].nil?

          ["sibilant", [series, name].sort.join("/"), "#{list[index]}#{st[:final]}#{tone}"]
        end
      end

      def coda_partners(st, tone)
        return [] unless %w[n ng].include?(st[:coda])

        other = (st[:coda] == "n") ? "ng" : "n"
        [["coda", "#{st[:nucleus]}n/#{st[:nucleus]}ng", "#{st[:initial]}#{st[:medial]}#{st[:nucleus]}#{other}#{tone}"]]
      end

      def families(chunks)
        merged = Hash.new { |hash, label| hash[label] = [0, 0] }
        chunks.each do |chunk|
          chunk[:families].each do |label, (hit, total)|
            merged[label][0] += hit
            merged[label][1] += total
          end
        end

        merged
          .reject { |_, (_, total)| total < 30 }
          .sort
          .to_h { |label, (hit, total)| [label, {"accuracy" => (100.0 * hit / total).round(1), "n" => total}] }
      end

      def norm_of(features)
        @store.norm_for(position: features["_index"].to_i, total: features["_n_syllables"].to_i)
      end

      def rivals_for(key, norm)
        @rivals ||= {}
        @rivals[[key, norm]] ||= Rivals.for(key, store: @store, norm: norm)
      end

      def syllable_score(analyzer, features, template, norm)
        parts = analyzer.part_scores(analyzer.score_axes(features, template, norm))
        return nil if parts.empty?

        weights = Acoustic::Weights::BASE.slice(*parts.map { |p| p["id"] })
        {overall: analyzer.weighted_overall(parts, weights), parts: parts.to_h { |p| [p["id"], p["score"]] }}
      end

      def top1(chunks)
        hit = chunks.sum { |c| c[:top1][0] }
        total = chunks.sum { |c| c[:top1][1] }
        {"value" => total.zero? ? 0.0 : (hit.to_f / total).round(4), "n" => total}
      end

      def contrasts(chunks)
        merged = Hash.new { |hash, cell| hash[cell] = {self: [], rival: []} }
        chunks.each do |chunk|
          chunk[:pairs].each do |cell, sides|
            merged[cell][:self].concat(sides[:self].compact)
            merged[cell][:rival].concat(sides[:rival].compact)
          end
        end

        merged.to_h { |cell, sides| [cell, separation(sides[:self], sides[:rival])] }
      end

      def separation(mine, theirs)
        return {"n" => 0} if mine.length < 30 || theirs.length < 30

        mu = mean(mine) - mean(theirs)
        pooled = Math.sqrt((variance(mine) + variance(theirs)) / 2.0).clamp(1e-6, Float::INFINITY)

        {
          "dprime" => (mu / pooled).round(3),
          "auc" => auc(mine, theirs).round(4),
          "self_median" => median(mine),
          "rival_median" => median(theirs),
          "n" => mine.length
        }
      end

      def auc(mine, theirs)
        all = (mine.map { |v| [v, 1] } + theirs.map { |v| [v, 0] }).sort_by(&:first)
        ranks = Array.new(all.length)
        index = 0
        while index < all.length
          last = index
          last += 1 while last + 1 < all.length && all[last + 1][0] == all[index][0]
          average = ((index + 1) + (last + 1)) / 2.0
          (index..last).each { |i| ranks[i] = average }
          index = last + 1
        end

        rank_sum = all.each_with_index.sum { |(_, positive), i| positive == 1 ? ranks[i] : 0 }
        (rank_sum - (mine.length * (mine.length + 1) / 2.0)) / (mine.length.to_f * theirs.length)
      end

      def natives(chunks)
        scores = chunks.flat_map { |c| c[:overall] }
        levels = chunks.each_with_object(Hash.new(0)) { |c, acc| c[:levels].each { |k, v| acc[k] += v } }
        total = levels.values.sum

        {
          "median" => median(scores),
          "p10" => scores.sort[(scores.length * 0.10).floor] || 0,
          "green" => total.zero? ? 0.0 : (100.0 * levels["green"] / total).round(1),
          "red_or_worse" => total.zero? ? 0.0 : (100.0 * (levels["red"] + levels["dark"]) / total).round(1),
          "n" => total
        }
      end

      def mean(values) = values.sum.to_f / values.length

      def variance(values)
        m = mean(values)
        values.sum { |v| (v - m) ** 2 } / values.length.to_f
      end

      def median(values) = values.sort[values.length / 2] || 0
    end
  end
end
