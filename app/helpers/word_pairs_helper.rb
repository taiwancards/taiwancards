# frozen_string_literal: true

module WordPairsHelper
  COLUMNS = {2 => "sm:grid-cols-2", 3 => "sm:grid-cols-3"}.freeze
  WIDE_COLUMNS = {2 => "md:grid-cols-2", 3 => "md:grid-cols-3"}.freeze

  def pair_columns(count, wide: false) = (wide ? WIDE_COLUMNS : COLUMNS)[count.clamp(2, 3)]
end
