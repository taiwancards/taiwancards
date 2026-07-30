# frozen_string_literal: true

class ProcessCache
  Entry = Struct.new(:value, :expires_at)

  def initialize(ttl:, limit:)
    @ttl = ttl
    @limit = limit
    @entries = Concurrent::Map.new
  end

  def read(key)
    held = @entries[key]
    return nil if held.nil? || held.expires_at <= now

    held
  end

  def write(key, value)
    clear if @entries.size >= @limit
    @entries[key] = Entry.new(value, now + @ttl)
    value
  end

  def fetch(key)
    held = read(key)
    return held.value if held

    write(key, yield)
  end

  def once(key)
    return false if read(key)

    write(key, true)
    true
  end

  def clear
    @entries.clear
  end

  def size = @entries.size

  private

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
