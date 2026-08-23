# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class ContextNorms
      PATH = "context_norms.json"
      MIN_CELL = 40
      EDGE = 0

      def initialize(store: TemplateStore.instance, io: $stdout)
        @store = store
        @io = io
      end

      def call
        cells, timing = gather
        kept = cells.select { |_, curves| curves.length >= MIN_CELL }
        @io&.puts("  tone cells #{kept.length} of #{cells.length}, tokens #{cells.values.sum(&:length)}")
        stretch = lengths(timing)
        @io&.puts("  duration by position #{stretch.map { |k, v| "#{k} ×#{v}" }.join(", ")}")

        {
          "generated_at" => Time.current.utc.iso8601,
          "method" => "how connected corpus speech bends a syllable away from its pooled template: " \
            "the tone contour by the tones on either side, the voiced duration by position in the phrase",
          "min_cell" => MIN_CELL,
          "curves" => kept.transform_values { |curves| average(curves) },
          "duration" => stretch
        }
      end

      def write!
        payload = call
        File.write(File.join(@store.root, PATH), JSON.pretty_generate(payload))
        Acoustic::ContextNorms.reset!
        payload
      end

      private

      def gather
        cells = Hash.new { |hash, cell| hash[cell] = [] }
        timing = Hash.new { |hash, spot| hash[spot] = [] }

        recordings.each_value do |group|
          next if group.length < 2

          group.sort_by! { |row| row["_index"].to_i }
          tones = group.map { |row| tone_of(row["_key"]) }

          group.each_with_index do |row, index|
            spot = Acoustic::ContextNorms.position(index, group.length)
            timing[spot] << stretch_of(row, index, group.length)
            deviation = deviation_of(row, index, group.length) or next
            cells[Acoustic::ContextNorms.cell(tones[index], tones[index - 1] || EDGE, tones[index + 1] || EDGE)] <<
              deviation
          end
        end

        [cells, timing]
      end

      def stretch_of(row, index, total)
        spoken = row["voiced_ms"].to_f
        return nil unless spoken.positive?

        template = @store.template(row["_key"], @store.norm_for(position: index, total: total)) ||
          @store.template(row["_key"])
        wanted = template&.dig("voiced_ms", "median").to_f
        wanted.positive? ? spoken / wanted : nil
      end

      def lengths(timing)
        timing
          .filter_map do |spot, ratios|
            usable = ratios.compact
            next if usable.length < MIN_CELL

            [spot, DTW::Statistics.median(usable).round(3)]
          end
          .to_h
      end

      def recordings
        found = Hash.new { |hash, file| hash[file] = [] }

        Tokens.available.each do |key|
          Tokens.each(key, raw: true) do |row|
            next if row["_n_syllables"].to_i < 2

            found[row["_file"]] << row.merge("_key" => key)
          end
        end

        found
      end

      def deviation_of(row, index, total)
        tone = tone_of(row["_key"])
        return nil if tone.zero?

        spoken = row["tone_curve"]
        return nil if spoken.blank?

        template = @store.template(row["_key"], @store.norm_for(position: index, total: total)) ||
          @store.template(row["_key"])
        centre = template&.dig("tone_contour", "center")
        return nil if centre.nil? || centre.length != spoken.length

        spoken.each_index.map { |i| (spoken[i] - centre[i]).round(4) }
      end

      def tone_of(key)
        Acoustic::Syllables.parse_key(key)&.last.to_i
      end

      def average(curves)
        length = curves.first.length
        Array.new(length) { |i| (curves.sum { |curve| curve[i] } / curves.length.to_f).round(4) }
      end
    end
  end
end
