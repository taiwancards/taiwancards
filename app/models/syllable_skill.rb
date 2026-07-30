# frozen_string_literal: true

class SyllableSkill < ApplicationRecord
  belongs_to :user

  ALPHA = 0.25
  RECENT_SPAN = 20
  CONFIDENT_AT = 3
  MASTERED_STREAK = 3
  SYSTEMATIC_Z = 1.0

  PARTS = %w[initial medial final tone].freeze

  TRACKED = %w[
    vot_ms
    centroid_ratio
    f1_ratio
    f2_ratio
    f2_end_ratio
    nasal_ratio_tail
    tone_range
    tone_slope
    duration_ms
  ]
    .freeze

  ERROR_CODES = %w[
    tone.wrong
    tone.shape
    initial.under_aspirated
    initial.over_aspirated
    initial.vot_off
    sibilant.too_front
    sibilant.too_back
    medial.weak
    vowel.open
    vowel.close
    vowel.front
    vowel.back
    coda.ng_for_n
    coda.n_for_ng
    duration.long
    duration.short
    duration.neutral_long
    timbre.drift
  ]
    .freeze

  scope :confident, -> { where(n: CONFIDENT_AT..) }
  scope :weakest, -> { confident.order(:ewma_overall) }

  def self.claim(user, key)
    syllable, tone = key.to_s.match(/\A([a-zü]+)([1-5])\z/)&.captures || [key.to_s, "0"]
    create_with(syllable:, tone: tone.to_i).find_or_create_by!(user:, syllable_key: key)
  end

  def record!(overall:, level:, parts: {}, deviations: {}, codes: [], heard: nil, at: Time.current)
    self.n += 1
    self.first_seen_at ||= at
    self.last_seen_at = at

    if overall
      self.best = [best.to_i, overall].max
      self.ewma_overall = blend(ewma_overall, overall)
      self.recent = (recent + [overall]).last(RECENT_SPAN)
    end

    bump_level(level)
    PARTS.each { |part| apply_part(part, parts[part]) }
    apply_deviations(deviations)
    apply_codes(codes)
    apply_heard(heard)

    save!
    self
  end

  def tone_confusions
    return {} if heard_tones.blank?

    heard_tones
      .each_with_index
      .filter_map { |count, index| [index + 1, count] if count.to_i.positive? && index + 1 != tone }
      .to_h
  end

  def mean_z(field)
    i = TRACKED.index(field) or return nil
    count = at(z_n, i).to_i
    return nil if count.zero?

    at(z_sum, i).to_f / count
  end

  def systematic
    TRACKED
      .filter_map do |field|
        value = mean_z(field)
        next if value.nil? || value.abs < SYSTEMATIC_Z
        next if at(z_n, TRACKED.index(field)).to_i < CONFIDENT_AT

        {"field" => field, "z" => value.round(2), "n" => at(z_n, TRACKED.index(field))}
      end
      .sort_by { |row| -row["z"].abs }
  end

  def habitual_error
    return nil if error_counts.blank?

    index = error_counts.each_with_index.max_by { |count, _| count }&.last
    return nil if index.nil? || error_counts[index].to_i < 2

    {"code" => ERROR_CODES[index], "n" => error_counts[index]}
  end

  def trend
    return nil if recent.length < 6

    half = recent.length / 2
    older = recent.first(half)
    newer = recent.last(half)
    ((newer.sum.to_f / newer.length) - (older.sum.to_f / older.length)).round(1)
  end

  def confident? = n >= CONFIDENT_AT

  def mastered? = streak >= MASTERED_STREAK

  def accuracy = n.zero? ? 0.0 : (n_green + n_amber).to_f / n

  private

  def blend(current, value)
    current.nil? ? value.to_f : current + (ALPHA * (value - current))
  end

  def bump_level(level)
    case level
    when "green"
      self.n_green += 1
      self.streak += 1
    when "amber"
      self.n_amber += 1
      self.streak = 0
    when "red"
      self.n_red += 1
      self.streak = 0
    when "dark"
      self.n_dark += 1
      self.streak = 0
    end
  end

  def apply_part(part, score)
    return if score.nil?

    send(:"ewma_#{part}=", blend(send(:"ewma_#{part}"), score))
  end

  def apply_deviations(deviations)
    sums = pad(z_sum, TRACKED.length, 0.0)
    counts = pad(z_n, TRACKED.length, 0)

    deviations.each do |field, value|
      i = TRACKED.index(field.to_s)
      next if i.nil? || value.nil?

      sums[i] += value.to_f
      counts[i] += 1
    end

    self.z_sum = sums
    self.z_n = counts
  end

  def apply_heard(heard)
    tone = heard.to_s[/([1-5])\z/, 1].to_i
    return if tone.zero?

    histogram = pad(heard_tones, 5, 0)
    histogram[tone - 1] += 1
    self.heard_tones = histogram
  end

  def apply_codes(codes)
    histogram = pad(error_counts, ERROR_CODES.length, 0)
    Array(codes).each do |code|
      i = ERROR_CODES.index(code.to_s)
      histogram[i] += 1 if i
    end

    self.error_counts = histogram
  end

  def pad(array, size, fill)
    values = Array(array).dup
    values << fill while values.length < size
    values.first(size)
  end

  def at(array, index)
    index.nil? ? nil : Array(array)[index]
  end
end
