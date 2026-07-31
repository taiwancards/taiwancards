# frozen_string_literal: true

module Study
  class Preferences
    PREFS_KEY = "study"

    RANGES = {
      "desired_retention" => 0.7..0.99,
      "daily_new_limit" => 0..500,
      "session_size" => 1..200,
      "learn_ahead_minutes" => 0..120
    }.freeze

    KEYS = RANGES.keys.freeze

    class << self
      def for(user = Current.user, settings: Setting.instance)
        new(user, settings)
      end

      def clamp(key, value)
        range = RANGES.fetch(key)
        return nil if value.blank?

        cast = key == "desired_retention" ? value.to_f : value.to_i
        cast.clamp(range.begin, range.end)
      end

      def sanitize(attributes)
        KEYS
          .filter_map { |key| [key, clamp(key, attributes[key])] if attributes.key?(key) }
          .to_h
          .compact
      end
    end

    def initialize(user, settings)
      @user = user
      @settings = settings
    end

    attr_reader :settings

    delegate :pron_auto, :study_display, to: :settings

    def desired_retention = resolve("desired_retention")

    def daily_new_limit = resolve("daily_new_limit")

    def session_size = resolve("session_size")

    def learn_ahead_minutes = resolve("learn_ahead_minutes")

    def overrides
      @overrides ||= @user.is_a?(User) ? (@user.prefs[PREFS_KEY] || {}) : {}
    end

    def customized?(key) = overrides.key?(key.to_s)

    def fsrs_parameters
      Fsrs::Parameters.default(
        desired_retention:,
        weights: settings.data["fsrs_weights"].presence || Fsrs::DEFAULT_WEIGHTS
      )
    end

    private

    def resolve(key)
      self.class.clamp(key, overrides[key]) || settings.public_send(key)
    end
  end
end
