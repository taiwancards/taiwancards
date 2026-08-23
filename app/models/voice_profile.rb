# frozen_string_literal: true

class VoiceProfile < ApplicationRecord
  belongs_to :user

  F0_MIN = 60.0
  F0_MAX = 400.0
  BINS = 40
  BIN_WIDTH = (F0_MAX - F0_MIN) / BINS

  CANONICAL_F3 = 3000.0

  MIN_FRAMES = 200
  MIN_TONE_OBSERVATIONS = 20
  TONES = [1, 2, 3, 4].freeze
  DYNAMIC_TONES = [2, 4].freeze

  FALLBACK_F3 = {"male" => 2750.0, "female" => 3250.0}.freeze
  PITCH_SPLIT_HZ = 165.0
  F3_DISAGREEMENT = 550.0

  def self.bin_for(hz)
    return nil if hz.nil? || hz <= F0_MIN || hz >= F0_MAX

    ((hz - F0_MIN) / BIN_WIDTH).floor.clamp(0, BINS - 1)
  end

  def self.bin_center(index)
    F0_MIN + ((index + 0.5) * BIN_WIDTH)
  end

  def observe_f0!(values, tone: nil, replace: false)
    hist = (f0_hist.presence || Array.new(BINS, 0)).dup
    per_tone = f0_by_tone.dup
    stored = replace ? nil : per_tone[tone.to_s].presence
    tone_hist = tone ? (stored || Array.new(BINS, 0)).dup : nil

    counted = 0
    Array(values).each do |hz|
      i = self.class.bin_for(hz)
      next unless i

      hist[i] += 1
      tone_hist[i] += 1 if tone_hist
      counted += 1
    end

    return self if counted.zero?

    per_tone[tone.to_s] = tone_hist if tone_hist
    self.f0_hist = hist
    self.f0_by_tone = per_tone
    self.n_calibration_frames = n_calibration_frames + counted
    self
  end

  def percentile(p, hist = f0_hist, min: MIN_FRAMES)
    return nil if hist.blank?

    total = hist.sum
    return nil if total < min

    target = total * p
    acc = 0
    hist.each_with_index do |count, i|
      acc += count
      return self.class.bin_center(i) if acc >= target
    end

    nil
  end

  def f0_median = percentile(0.5)
  def f0_low = percentile(0.05)
  def f0_high = percentile(0.95)

  def warp
    f3 = trusted_f3
    return 1.0 unless f3

    (f3 / CANONICAL_F3).clamp(0.75, 1.35)
  end

  def expected_f3
    hz = f0_median
    return FALLBACK_F3[declared_gender] if hz.nil? || hz <= 0

    FALLBACK_F3[hz < PITCH_SPLIT_HZ ? "male" : "female"]
  end

  def trusted_f3
    measured = f3_ref
    expected = expected_f3
    return measured || expected if measured.nil? || expected.nil?

    (measured - expected).abs > F3_DISAGREEMENT ? expected : measured
  end

  def f3_disagrees? = f3_ref.present? && expected_f3.present? && (f3_ref - expected_f3).abs > F3_DISAGREEMENT

  def tone_anchor(tone)
    hist = f0_by_tone[tone.to_s]
    return nil if hist.blank? || hist.sum < MIN_TONE_OBSERVATIONS

    percentile(0.5, hist, min: MIN_TONE_OBSERVATIONS)
  end

  def anchors = TONES.filter_map { |tone| tone_anchor(tone) }

  def tone_span_semitones
    high = tone_anchor(1)
    low = tone_anchor(3)
    return nil unless high && low && low.positive?

    span = 12.0 * Math.log2(high / low)
    span.positive? ? span : nil
  end

  def reference_hz
    found = anchors
    return f0_median if found.empty?

    Math.exp(found.sum { |hz| Math.log(hz) } / found.length)
  end

  def histogram_span(tone)
    hist = f0_by_tone[tone.to_s]
    return nil if hist.blank? || hist.sum < MIN_TONE_OBSERVATIONS

    low = percentile(0.10, hist, min: MIN_TONE_OBSERVATIONS)
    high = percentile(0.90, hist, min: MIN_TONE_OBSERVATIONS)
    return nil unless low && high && low.positive?

    12.0 * Math.log2(high / low)
  end

  def tone_excursion_semitones
    spans = DYNAMIC_TONES.filter_map { |tone| histogram_span(tone) }
    return nil if spans.empty?

    spans.sum / spans.length
  end

  MIN_TONE_SPAN = 3.0
  MAX_TONE_SPAN = 24.0

  def anchors_sane?
    high = tone_anchor(1)
    low = tone_anchor(3)
    return true if high.nil? || low.nil? || low <= 0

    (12.0 * Math.log2(high / low)).between?(MIN_TONE_SPAN, MAX_TONE_SPAN)
  end

  OCTAVE_SPAN = 9.0
  OCTAVE_STEPS = 4

  def octave_corrected(hz)
    ref = reference_hz
    value = hz.to_f
    return value unless ref && ref > F0_MIN && value > F0_MIN

    OCTAVE_STEPS.times do
      drift = 12.0 * Math.log2(value / ref)
      break if drift.abs <= OCTAVE_SPAN

      value = drift.positive? ? value / 2.0 : value * 2.0
    end

    value
  end

  PLAUSIBLE_F3 = (2000.0..4100.0)

  def calibrated? = calibrated_at.present? && PLAUSIBLE_F3.cover?(f3_ref.to_f)

  def tone_calibrated? = tone_span_semitones.present?

  def summary
    {
      calibrated: calibrated?,
      tone_calibrated: tone_calibrated?,
      f0_low: f0_low&.round,
      f0_median: f0_median&.round,
      f0_high: f0_high&.round,
      f3_ref: f3_ref&.round,
      warp: warp.round(3),
      tone_span_semitones: tone_span_semitones&.round(1),
      tone_excursion_semitones: tone_excursion_semitones&.round(1),
      tones_measured: TONES.count { |tone| tone_anchor(tone) },
      anchors_sane: anchors_sane?,
      n_frames: n_calibration_frames,
      n_attempts: n_attempts,
      calibrated_at: calibrated_at
    }
  end
end
