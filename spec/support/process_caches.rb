# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    ActivityEvent.forget_seen
    ContentCache.process.clear
  end
end
