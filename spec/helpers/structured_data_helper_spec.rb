# frozen_string_literal: true

require "rails_helper"

RSpec.describe StructuredDataHelper do
  describe "#structured_data" do
    it "keeps a value that spells a closing script tag inside the JSON-LD block" do
      html = helper.structured_data("name" => "</script><script>alert(1)</script>")
      scripts = Nokogiri::HTML5.fragment(html).css("script")

      expect(scripts.size).to(eq(1))
      expect(scripts.first["type"]).to(eq("application/ld+json"))
      expect(JSON.parse(scripts.first.text)).to(
        eq("name" => "</script><script>alert(1)</script>", "@context" => "https://schema.org")
      )
    end

    it "leaves the Chinese text readable" do
      expect(helper.structured_data("name" => "自由")).to(include("\"name\":\"自由\""))
    end

    it "renders nothing for an empty payload" do
      expect(helper.structured_data({})).to(be_nil)
    end
  end
end
