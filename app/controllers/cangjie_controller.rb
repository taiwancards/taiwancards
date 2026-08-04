# frozen_string_literal: true

class CangjieController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable
  DATA = "cangjie5.json"

  def show
    @rows = Huayu::Cangjie::ROWS
    @keys = Huayu::Cangjie::KEYS
    @available = SharedAssets.carried?("json", CangjieController::DATA)
  end
end
