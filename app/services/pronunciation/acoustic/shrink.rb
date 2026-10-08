# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Shrink
      MIN_KEYS = 12
      MIN_TAU_SHARE = 0.01
      MEDIAN_NOISE = Math::PI / 2
      MIN_WITHIN = 0.05
      PRIOR_DF = 10.0

      TONE = -> (tpl) { tpl["tone"].to_i }

      CENTERS = {TONE => (ToneMarks::DERIVED + %w[f0_register tone_range tone_slope]).freeze}.freeze
      SPREADS = {
        TONE => (ToneMarks::DERIVED + %w[f0_register tone_range tone_slope duration_ms voiced_ms voiced_ratio]).freeze
      }.freeze

      module_function

      def apply!(templates)
        walk(templates, CENTERS) { |group, field| pull(group, field) }
        walk(templates, SPREADS) { |group, field| moderate(group, field) }
        templates
      end

      def walk(templates, plan)
        plan.each do |classify, fields|
          templates.group_by(&classify).each_value do |group|
            next if group.length < MIN_KEYS

            fields.each { |field| yield(group, field) }
          end
        end
      end

      def pull(group, field)
        stats = group.filter_map { |tpl| tpl[field] if usable?(tpl[field]) }
        return if stats.length < MIN_KEYS

        medians = stats.map { |stat| center(stat) }
        prior = DTW::Statistics.median(medians)
        noise = stats.map { |stat| error_variance(stat) }
        tau = between(medians, noise)

        stats.each_with_index do |stat, index|
          weight = tau.positive? ? tau / (tau + noise[index]) : 0.0
          stat["median_own"] = medians[index]
          stat["median"] = prior + ((medians[index] - prior) * weight)
          stat["prior"] = prior
          stat["weight"] = weight
        end
      end

      def moderate(group, field)
        stats = group.filter_map { |tpl| tpl[field] if usable?(tpl[field]) }
        return if stats.length < MIN_KEYS

        variances = stats.map { |stat| within(stat) ** 2 }
        pooled = DTW::Statistics.median(variances)
        return unless pooled.positive?

        stats.each_with_index do |stat, index|
          df = [stat["n"].to_i - 1, 0].max
          settled = ((df * variances[index]) + (PRIOR_DF * pooled)) / (df + PRIOR_DF)
          stat["sigma_within_own"] = within(stat)
          stat["sigma_within"] = Math.sqrt(settled)
          stat["sigma"] = Variability.combine(stat["sigma_within"], stat["sigma_between"].to_f)
        end
      end

      def between(medians, noise)
        spread = DTW::Statistics.median_absolute_deviation(medians) ** 2
        [spread - (noise.sum / noise.length), MIN_TAU_SHARE * spread].max
      end

      def usable?(stat) = stat.is_a?(Hash) && stat["median"] && stat["n"].to_i.positive?

      def center(stat) = (stat["median_own"] || stat["median"]).to_f

      def within(stat)
        [stat["sigma_within_own"] || stat["sigma_within"] || stat["mad"], MIN_WITHIN].max.to_f
      end

      def error_variance(stat)
        value = within(stat)
        MEDIAN_NOISE * value * value / stat["n"].to_i
      end
    end
  end
end
