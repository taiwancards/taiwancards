# frozen_string_literal: true

class ConfigurationsController < ApplicationController
  def show
    render(
      json: {
        settings: {},
        rules: [
          {
            patterns: ["/new$", "/edit$"],
            properties: {context: "modal"}
          },
          {
            patterns: [".*"],
            properties: {context: "default", pull_to_refresh_enabled: true}
          }
        ]
      }
    )
  end
end
