# frozen_string_literal: true

module Scans
  module Settings
    DEFAULT_MODEL = "claude-sonnet-5-5"

    module_function

    def model = ScanCredential.current.chosen_model || environment_model

    def environment_model = ENV["SCAN_MODEL"].presence || DEFAULT_MODEL

    def models = Pricing::PER_MILLION.keys

    def key = ScanCredential.current.api_key

    def configured? = key.present?

    def usable? = ScanCredential.current.usable?

    def global_daily = positive("SCAN_GLOBAL_DAILY", 300)

    def client_daily = positive("SCAN_CLIENT_DAILY", 30)

    def concurrency = positive("SCAN_CONCURRENCY", 3)

    def positive(name, default)
      value = ENV[name].to_i
      value.positive? ? value : default
    end
  end
end
