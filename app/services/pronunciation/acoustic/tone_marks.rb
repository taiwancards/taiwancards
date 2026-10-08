# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module ToneMarks
      NUCLEUS = (0.25..0.80)
      MIN_POINTS = 8
      MIN_CORE = 4

      LEVELS = %w[mark_onset mark_q1 mark_mid mark_q3 mark_end].freeze

      WEIGHT = {
        "mark_onset" => 1.90,
        "mark_q1" => 1.82,
        "f0_register" => 1.61,
        "mark_mid" => 1.50,
        "mark_q3" => 1.43,
        "tone_slope" => 1.33,
        "mark_late" => 1.28,
        "mark_end" => 1.27,
        "mark_minpos" => 1.14,
        "tone_range" => 1.11,
        "mark_early" => 0.94,
        "mark_curve" => 0.76,
        "voiced_ratio" => 0.60,
        "energy_tail_db" => 0.44
      }.freeze

      FIELDS = WEIGHT.keys.freeze
      DERIVED = (LEVELS + %w[mark_early mark_late mark_curve mark_minpos]).freeze
      HEIGHT = (LEVELS + ["f0_register"]).freeze

      module_function

      def core(curve)
        return nil if curve.nil? || curve.length < MIN_POINTS

        from = (curve.length * NUCLEUS.begin).round
        to = (curve.length * NUCLEUS.end).round
        part = curve[from..to]
        part && part.length >= MIN_CORE ? part : nil
      end

      def of(curve, register)
        part = core(curve)
        return nil if part.nil?

        shift = register.to_f
        last = part.length - 1
        quarter = part.length / 4
        middle = part.length / 2

        {
          "mark_onset" => part[0] + shift,
          "mark_q1" => part[quarter] + shift,
          "mark_mid" => part[middle] + shift,
          "mark_q3" => part[(3 * part.length) / 4] + shift,
          "mark_end" => part[last] + shift,
          "mark_early" => part[part.length / 3] - part[0],
          "mark_late" => part[last] - part[(2 * part.length) / 3],
          "mark_curve" => ((part[0] + part[last]) / 2.0) - part[middle],
          "mark_minpos" => part.each_with_index.min_by { |value, _| value }[1].to_f / last
        }
      end

      def stamp!(row)
        marks = of(row["tone_curve"], row["f0_register"])
        return row if marks.nil?

        row.merge!(row["f0_register"].nil? ? marks.except(*LEVELS) : marks)
      end

      def heard?(features) = features["f0_register"].present?

      def centered(values)
        middle = values.sum / values.length
        values.map { |value| value - middle }
      end

      def offsets(plain, placed)
        return {} if plain.nil? || placed.nil? || plain == placed

        before = of(plain, 0.0)
        after = of(placed, 0.0)
        return {} if before.nil? || after.nil?

        DERIVED.to_h { |field| [field, after[field] - before[field]] }
      end

      def deviations(features, template, sigma_of, shifts = {})
        marks = of(features["tone_curve"], features["f0_register"])
        return nil if marks.nil?

        wanted = template.slice(*FIELDS)
        return nil unless wanted["mark_mid"]

        lift = level_lift(marks, wanted, heard?(features))
        trust = Math.sqrt(register_share(features["n_register"]))
        FIELDS.filter_map do |field|
          stat = wanted[field]
          value = marks.key?(field) ? marks[field] : features[field]
          next if stat.nil? || stat["median"].nil? || value.nil?

          base = stat["median"] + shifts.fetch(field, 0.0) + (LEVELS.include?(field) ? lift : 0.0)
          z = (value - base) / sigma_of.call(stat, field)
          z *= OVERSHOOT if overshoot?(field, value, base)
          [field, HEIGHT.include?(field) ? z * trust : z]
        end
      end

      OVERSHOOT = 0.5
      LENIENT = %w[tone_slope mark_early mark_late].freeze

      def overshoot?(field, value, base)
        LENIENT.include?(field) && value * base > 0 && value.abs > base.abs
      end

      REGISTER_SHARE = {2 => 0.5, 3 => 0.75}.freeze

      def register_share(heard)
        return 1.0 if heard.nil?

        REGISTER_SHARE.fetch(heard.to_i, 1.0)
      end

      def level_lift(marks, wanted, heard)
        return 0.0 if heard

        mine = LEVELS.filter_map { |field| marks[field] }
        theirs = LEVELS.filter_map { |field| wanted.dig(field, "median") }
        return 0.0 if mine.length != LEVELS.length || theirs.length != LEVELS.length

        (mine.sum / mine.length) - (theirs.sum / theirs.length)
      end

      WORST = 3

      def aggregate(zs)
        return nil if zs.empty?

        scale = Math.sqrt(zs.map { |field, _| WEIGHT.fetch(field, 1.0) }.max)
        worst = zs
          .map { |field, z| z.abs * Math.sqrt(WEIGHT.fetch(field, 1.0)) }
          .max(WORST)

        (worst.sum / worst.length) / scale
      end

      def band(template, center, sigma_of)
        stats = LEVELS.map { |field| template[field] }
        return nil if stats.any?(&:nil?) || stats.any? { |stat| stat["median"].nil? }

        widths = stats.each_with_index.map { |stat, index| sigma_of.call(stat, LEVELS[index]) }
        from = (center.length * NUCLEUS.begin).round
        to = (center.length * NUCLEUS.end).round
        span = [to - from, 1].max

        center.each_index.map do |index|
          position = ((index - from).to_f / span).clamp(0.0, 1.0)
          half = interpolate(widths, position)
          [(center[index] - half).round(3), (center[index] + half).round(3)]
        end
      end

      def interpolate(widths, position)
        x = position * (widths.length - 1)
        low = x.floor
        high = [low + 1, widths.length - 1].min
        widths[low] + ((widths[high] - widths[low]) * (x - low))
      end
    end
  end
end
