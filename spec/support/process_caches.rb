# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    ActivityEvent.forget_seen
    ContentCache.process.clear
    Setting.reset_cache!
    Huayu::TextAnalyzer.reset_vocabulary!
  end
end
