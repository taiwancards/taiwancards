# frozen_string_literal: true

require "rails_helper"

# TODO
# Temporary spec -- just cuz Rails isn't yet updated towards json 3.+

RSpec.describe JsonKeywordDecoding do
  it "decodes with the keyword options json 3 expects" do
    expect(ActiveSupport::JSON.decode("{\"a\": 1}", symbolize_names: true)).to(eq({a: 1}))
  end

  it "keeps load on the patched decoder, not on the aliased original" do
    expect(ActiveSupport::JSON.load("{\"a\": [1, 2]}")).to(eq({"a" => [1, 2]}))
  end

  it "is still needed, because Rails passes the options positionally" do
    upstream = ActiveSupport::JSON.method(:decode).super_method

    expect { upstream.call("{}") }.to(
      raise_error(ArgumentError),
      "All ok, Rails got updated -- drop config/initializers/json_decoding.rb + this spec"
    )
  end
end
