# frozen_string_literal: true

module Scans
  module KeyCheck
    TIMEOUT = 10
    OUTCOMES = %i[ok rejected no_model unreachable].freeze

    module_function

    def call(key, model: Settings.model, client: nil)
      require "anthropic"

      client ||= Anthropic::Client.new(api_key: key.reveal, timeout: TIMEOUT, max_retries: 0)
      client.models.retrieve(model)
      :ok
    rescue StandardError => error
      outcome_for(error)
    end

    def outcome_for(error)
      Rails.logger.warn("scan key check: #{error.class.name}#{" #{error.status}" if error.respond_to?(:status)}")
      return :unreachable unless defined?(Anthropic::Errors)

      case error
      when Anthropic::Errors::AuthenticationError, Anthropic::Errors::PermissionDeniedError
        :rejected
      when Anthropic::Errors::NotFoundError
        :no_model
      else
        :unreachable
      end
    end
  end
end
