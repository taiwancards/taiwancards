# frozen_string_literal: true

require "json"

module Pronunciation
  module Acoustic
    module Junctions
      VOICED_CONFIDENCE = 0.5
      EDGE_FRAMES = 3
      MAX_GAP_MS = 600.0

      STOPS = %w[b p d t g k].freeze
      AFFRICATES = %w[z c zh ch j q].freeze
      NASALS = %w[m n].freeze
      DEFAULT_CELL = "all"

      module_function

      def cell(key)
        syllable, = Syllables.parse_key(key)
        return DEFAULT_CELL if syllable.nil?

        initial = Phonology.analyze(syllable)[:initial].to_s
        return "vowel" if initial.empty?
        return "stop" if STOPS.include?(initial)
        return "affricate" if AFFRICATES.include?(initial)
        return "nasal" if NASALS.include?(initial)

        "fricative"
      end

      FLOOR = {"gap_ms" => 40.0, "f0_jump" => 1.2, "dip_db" => 4.0}.freeze
      MEASURES = FLOOR.keys.freeze
      NORMS_FILE = "junction_norms.json"

      def norms(store = TemplateStore.instance)
        @norms ||= {}
        @norms[store.root] ||= read_norms(store)
      end

      def reset! = @norms = {}

      def read_norms(store)
        path = File.join(store.root, NORMS_FILE)
        return {} unless File.exist?(path)

        JSON.parse(File.read(path))["classes"] || {}
      rescue JSON::ParserError
        {}
      end

      def score(analysis, spans, keys, store: TemplateStore.instance)
        return nil if spans.length < 2

        table = norms(store)
        return nil if table.empty?

        rows = measure(analysis, spans).each_with_index.filter_map do |junction, index|
          next if junction.nil?

          judged(junction, table, cell(keys[index + 1]))
        end

        return nil if rows.empty?

        worst = rows.min_by { |row| row["score"] }
        {
          "score" => (rows.sum { |row| row["score"] } / rows.length).round,
          "code" => headline(rows, worst),
          "worst" => worst,
          "junctions" => rows
        }
      end

      def headline(rows, worst)
        mean = rows.sum { |row| row["strain"] } / rows.length
        mean < OK_STRAIN ? "flow.ok" : worst["code"]
      end

      def judged(junction, table, cell)
        reference = table[cell] || table[DEFAULT_CELL] || {}
        excess = MEASURES.to_h { |name| [name, strain(junction[name], reference[name], FLOOR[name])] }
        strained = Math.sqrt(excess.values.sum { |value| value * value } / excess.length)

        junction.merge(
          "cell" => cell,
          "strain" => strained.round(3),
          "score" => (100.0 * Math.exp(-(strained ** 2) / 2.0)).round,
          "code" => code_for(excess, strained)
        )
      end

      OK_STRAIN = 1.0

      def code_for(excess, strained)
        return "flow.ok" if strained < OK_STRAIN

        case excess.max_by { |_, value| value }.first
        when "f0_jump"
          "flow.pitch_reset"
        when "dip_db"
          "flow.clipped"
        else
          "flow.choppy"
        end
      end

      def strain(value, reference, floor)
        return 0.0 if value.nil? || reference.nil?

        high = reference["p75"].to_f
        return 0.0 if value <= high

        (value - high) / [reference["p90"].to_f - high, floor].max
      end

      def measure(analysis, spans)
        edges = spans.map { |span| voiced_edges(analysis, span) }

        (0...(spans.length - 1)).map do |index|
          left = edges[index]
          right = edges[index + 1]
          next nil if left.nil? || right.nil?

          {
            "index" => index,
            "gap_ms" => gap_ms(left, right),
            "f0_jump" => f0_jump(analysis, left, right),
            "dip_db" => dip_db(analysis, left, right)
          }
        end
      end

      def voiced_edges(analysis, span)
        return nil if span.nil?

        low, high = span
        conf = analysis[:conf]
        start = (low..high).find { |i| conf[i].to_f > VOICED_CONFIDENCE }
        return nil if start.nil?

        stop = high.downto(low).find { |i| conf[i].to_f > VOICED_CONFIDENCE }
        [start, stop || start]
      end

      def gap_ms(left, right)
        frames = right[0] - left[1] - 1
        (frames.negative? ? 0.0 : frames * Features::HOP_MS).clamp(0.0, MAX_GAP_MS)
      end

      def f0_jump(analysis, left, right)
        before = edge_pitch(analysis, left[1], -1)
        after = edge_pitch(analysis, right[0], 1)
        return nil if before.nil? || after.nil?

        DSP::Scales.hz_to_semitones(after, reference: before).abs.round(3)
      end

      def edge_pitch(analysis, frame, step)
        f0 = analysis[:f0]
        values = EDGE_FRAMES.times.filter_map do |offset|
          value = f0[frame + (offset * step)]
          value if value.to_f.positive?
        end

        values.empty? ? nil : DTW::Statistics.median(values)
      end

      def dip_db(analysis, left, right)
        energy = analysis[:energy]
        peak = [energy[left[1]].to_f, energy[right[0]].to_f].min
        floor = (left[1]..right[0]).map { |i| energy[i].to_f }.min
        (peak - floor).round(3)
      end
    end
  end
end
