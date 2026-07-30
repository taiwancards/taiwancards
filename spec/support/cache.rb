# frozen_string_literal: true

module CacheHelpers
  def with_cache
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = previous
  end
end

RSpec.configure { |config| config.include(CacheHelpers) }
