# frozen_string_literal: true

class HandwritingController < ApplicationController
  DATA = "hanzilookup-mmah.json"

  def show
    @available = SharedAssets.carried?("json", HandwritingController::DATA)
  end
end
