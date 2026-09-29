# frozen_string_literal: true

require "rails_helper"

RSpec.describe Newsletters::PlainText do
  it "turns the letter into readable text with links spelled out" do
    html = "<h1>News</h1><div>Line one<br>Line <a href=\"https://x.test/a\">two</a></div><ul><li>first</li><li>second</li></ul><img src=\"/i.png\">"

    expect(described_class.call(html)).to(eq("News\n\nLine one\nLine two (https://x.test/a)\n\n• first\n• second"))
  end
end
