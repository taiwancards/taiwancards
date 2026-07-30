# frozen_string_literal: true

class SentenceProfile < ApplicationRecord
  belongs_to :lexeme

  TOCFL_LEVELS = %w[Novice1 Novice2 A1 A2 B1 B2 C].freeze
  TBCL_GRADES = %w[1 2 3 4 5 6 7].freeze
  FREQ_BANDS = %w[100 300 500 700 1000 1500 2000 3000 4808 +6329].freeze
  FREQ_LIMITS = [100, 300, 500, 700, 1000, 1500, 2000, 3000, 4808, 4808 + 6329].freeze

  SCHEMES = {
    "tbcl" => {levels: TBCL_GRADES, index: :tbcl_index, exact: :tbcl_exact},
    "tocfl" => {levels: TOCFL_LEVELS, index: :tocfl_index, exact: :tocfl_exact},
    "freq" => {levels: FREQ_BANDS, index: :freq_index, exact: :freq_exact}
  }.freeze

  scope :ordered, -> { order(:difficulty, :id) }

  scope(
    :at_most,
    -> (scheme, level) {
      config = SCHEMES.fetch(scheme.to_s)
      position = config[:levels].index(level.to_s)
      next all if position.nil?

      where(config[:index] => ..(position + 1))
    }
  )

  scope(
    :guaranteed,
    -> (scheme) { where(SCHEMES.fetch(scheme.to_s)[:exact] => true) }
  )

  scope(
    :in_registers,
    -> (values) { values.present? ? where("registers && ARRAY[?]::integer[]", Array(values)) : all }
  )

  def self.visible_to(user)
    ids = ContentSource.visible_to(user).pluck(:id)
    return none if ids.empty?

    where("source_ids && ARRAY[?]::integer[]", ids)
  end

  def level_for(scheme)
    config = SCHEMES.fetch(scheme.to_s)
    position = self[config[:index]]
    return nil if position.nil?

    config[:levels][position - 1]
  end

  def exact_for?(scheme)
    self[SCHEMES.fetch(scheme.to_s)[:exact]]
  end
end
