# frozen_string_literal: true

require "action_dispatch/testing/integration"

module Offline
  class Renderer
    class Refused < StandardError
    end

    def initialize(host: "localhost")
      @host = host
    end

    def call(path, locale)
      address = "/#{locale}#{path}"
      session.get(address)
      response = session.response

      raise Refused, "#{address} answered #{response.status}" unless response.status == 200
      raise Refused, "#{address} answered with a session" if personal?(response.body)

      response.body
    end

    private

    def personal?(body) = body.include?("name=\"csrf-token\"")

    def session
      @session ||= begin
        opened = ActionDispatch::Integration::Session.new(Rails.application)
        opened.host = @host
        opened
      end
    end
  end
end
