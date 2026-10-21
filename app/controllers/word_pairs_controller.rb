# frozen_string_literal: true

class WordPairsController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable

  def index
    @levels = Huayu::WordPairs.levels
  end

  def show
    @pair = Huayu::WordPairs.find(params[:id])
    raise ActiveRecord::RecordNotFound if @pair.nil?

    @previous, @next = Huayu::WordPairs.neighbors(@pair)
  end
end
