# frozen_string_literal: true

module ProgressHelper
  ACTIVITY_SHADES = %w[bg-muted bg-emerald-500/30 bg-emerald-500/55 bg-emerald-500/80 bg-emerald-500].freeze

  def activity_shade(count, peak)
    return ACTIVITY_SHADES.first if count.zero?

    ACTIVITY_SHADES[(Math.sqrt(count.fdiv(peak)) * 4).ceil.clamp(1, 4)]
  end
end
