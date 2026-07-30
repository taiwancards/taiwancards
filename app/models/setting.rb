# frozen_string_literal: true

class Setting < ApplicationRecord
  DEFAULTS = {
    "desired_retention" => 0.9,
    "daily_new_limit" => 10,
    "session_size" => 12,
    "learn_ahead_minutes" => 20,
    "pron_auto_delay_ms" => 1000,
    "pron_auto_silence_ms" => 900,
    "pron_auto_max_ms" => 6000
  }.freeze

  DISPLAY_DEFAULTS = {"front" => "target", "reading" => "zhuyin", "examples" => true}.freeze
  FRONT_MODES = %w[target reading translation].freeze
  READING_MODES = %w[zhuyin pinyin].freeze

  def self.instance
    first || create!
  end

  def desired_retention
    fetch("desired_retention").to_f
  end

  def daily_new_limit
    fetch("daily_new_limit").to_i
  end

  def learn_ahead_minutes
    fetch("learn_ahead_minutes").to_i
  end

  def session_size
    fetch("session_size").to_i
  end

  def pron_auto
    {
      delay_ms: fetch("pron_auto_delay_ms").to_i,
      silence_ms: fetch("pron_auto_silence_ms").to_i,
      max_ms: fetch("pron_auto_max_ms").to_i
    }
  end

  def fsrs_parameters
    Fsrs::Parameters.default(
      desired_retention:,
      weights: data["fsrs_weights"].presence || Fsrs::DEFAULT_WEIGHTS
    )
  end

  def study_display
    DISPLAY_DEFAULTS.merge(data["study_display"] || {})
  end

  def update_study_display!(config)
    update!(data: data.merge("study_display" => study_display.merge(config)))
  end

  private

  def fetch(key)
    data[key] || DEFAULTS.fetch(key)
  end
end
