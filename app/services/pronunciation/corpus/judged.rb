# frozen_string_literal: true

module Pronunciation
  module Corpus
    class Judged
      CELLS = %w[overall tone initial final medial].freeze
      FALSE_ACCEPT = [0.05, 0.10, 0.20].freeze

      def initialize(rescore: false, store: TemplateStore.instance, io: nil)
        @rescore = rescore
        @store = store
        @io = io
      end

      def call
        points = collect
        return {"n" => 0} if points.empty?

        {
          "n" => points.length,
          "recordings" => points.map { |point| point[:recording] }.uniq.length,
          "accepted" => points.count { |point| point[:label] },
          "rejected" => points.count { |point| !point[:label] },
          "rescored" => @rescore,
          "cells" => CELLS.index_with { |cell| cell_report(points, cell) }.compact,
          "bands" => bands(points),
          "disagreements" => disagreements(points),
          "blamed" => blamed(points)
        }
      end

      private

      def collect
        PronunciationRecording.rated.oldest_first.flat_map { |recording| points_of(recording) }
      end

      def points_of(recording)
        scored = @rescore ? rescore(recording) : recording.syllables
        return [] if scored.blank?

        scored.each_with_index.filter_map do |syllable, index|
          label = recording.label_for(syllable["index"] || index)
          next if label.nil?

          {
            recording: recording.id,
            key: syllable["key"],
            label: label,
            level: syllable["level"],
            scores: {"overall" => syllable["overall"]}.merge(Hash(syllable["cells"]))
          }
        end
      end

      def rescore(recording)
        result = AcousticBackend
          .new(store: @store)
          .grade(audio: recording.audio, text: recording.text, syllables: recording.expected)
        return nil if result.nil? || result["status"] == "retry"

        Array(result["syllables"]).each_with_index.map do |syllable, index|
          {
            "key" => syllable["key"],
            "index" => index,
            "level" => syllable["level"],
            "overall" => syllable["overall"],
            "cells" => Hash(syllable["cells"]).transform_values { |cell| cell["score"] }.compact
          }
        end
      rescue StandardError => error
        @io&.puts("  #{recording.id}: #{error.class}")
        nil
      end

      def cell_report(points, cell)
        yes = points.select { |point| point[:label] }.filter_map { |point| point[:scores][cell] }
        no = points.reject { |point| point[:label] }.filter_map { |point| point[:scores][cell] }
        return nil if yes.length < 5 || no.length < 5

        {
          "n_accepted" => yes.length,
          "n_rejected" => no.length,
          "accepted_median" => median(yes),
          "rejected_median" => median(no),
          "auc" => auc(yes, no).round(4),
          "cuts" => FALSE_ACCEPT.index_with { |rate| cut_at(yes, no, rate) },
          "current" => Verdict.new.bounds(cell)
        }
      end

      def cut_at(yes, no, rate)
        allowed = (no.length * rate).floor
        cut = no.sort.reverse[allowed] || no.min
        {"green" => cut.to_i + 1, "keeps" => share(yes) { |v| v > cut }, "admits" => share(no) { |v| v > cut }}
      end

      def bands(points)
        points
          .group_by { |point| point[:level] }
          .transform_values { |group|
            {"n" => group.length, "accepted" => group.count { |point| point[:label] }}
          }
      end

      def disagreements(points)
        points
          .select { |point| (point[:level] == "green") != point[:label] }
          .group_by { |point| point[:label] ? "harsh" : "lenient" }
          .transform_values { |group| group.map { |point| point[:key] }.tally.sort_by { |_, n| -n }.first(10).to_h }
      end

      def blamed(points)
        points
          .select { |point| (point[:level] == "green") != point[:label] }
          .group_by { |point| point[:label] ? "harsh" : "lenient" }
          .transform_values { |group|
            group.filter_map { |point| weakest(point) }.tally.sort_by { |_, n| -n }.to_h
          }
      end

      def weakest(point)
        cells = point[:scores].except("overall").compact
        cells.empty? ? nil : cells.min_by { |_, score| score }.first
      end

      def share(values)
        return 0.0 if values.empty?

        (100.0 * values.count { |value| yield(value) } / values.length).round(1)
      end

      def median(values) = values.sort[values.length / 2]

      def auc(yes, no)
        return 0.5 if yes.empty? || no.empty?

        wins = yes.sum { |a| no.count { |b| a > b } + (0.5 * no.count { |b| a == b }) }
        wins.to_f / (yes.length * no.length)
      end
    end
  end
end
