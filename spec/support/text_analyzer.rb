# frozen_string_literal: true

RSpec.configure do |config|
  config.before { Huayu::TextAnalyzer.reset_vocabulary! }
  config.after { Huayu::TextAnalyzer.reset_vocabulary! }
end
