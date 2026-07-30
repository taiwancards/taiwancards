# frozen_string_literal: true

module ContentCache
  TTL = 12.hours
  PROCESS_TTL = 5.minutes
  PROCESS_ENTRIES = 512

  module_function

  def fetch(*key, &)
    id = key.flatten.compact.join("/")
    process.fetch(id) { Rails.cache.fetch(id, expires_in: TTL, &) }
  end

  def clear
    Rails.cache.clear
    process.clear
  end

  def process
    @process ||= ProcessCache.new(ttl: PROCESS_TTL, limit: PROCESS_ENTRIES)
  end
end
