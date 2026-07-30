# frozen_string_literal: true

module Sources
  Missing = Class.new(StandardError)

  class << self
    def url(key)
      ENV[key.to_s].presence || raise(Missing, "#{key} is not set — see .env.dev")
    end

    def url?(key) = ENV[key.to_s].present?

    def user_agent = ENV.fetch("CORPUS_USER_AGENT", "TaiwanCards/1.0")
  end
end
