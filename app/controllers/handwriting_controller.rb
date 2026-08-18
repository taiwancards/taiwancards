# frozen_string_literal: true

class HandwritingController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable
  DATA = "hanzilookup-mmah.json"

  def show
    @available = SharedAssets.carried?("json", HandwritingController::DATA)
  end
end
