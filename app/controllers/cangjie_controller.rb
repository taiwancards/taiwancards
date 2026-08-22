# frozen_string_literal: true

class CangjieController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable
  DATA = "cangjie5.json"

  def show
    @available = SharedAssets.carried?("json", DATA)
    @url = SharedAssets.url_for("json", DATA) if @available
  end
end
