# frozen_string_literal: true

module DeckPreviewHelpers
  PAYLOAD = /<script[^>]*id="deck-preview-data"[^>]*>(.*?)<\/script>/m

  def preview_payload
    JSON.parse(response.body[PAYLOAD, 1].to_s)
  end

  def preview_candidates
    preview_payload.fetch("candidates", []).map { |entry| entry["t"] }
  end
end

RSpec.configure do |config|
  config.include(DeckPreviewHelpers, type: :request)
end
