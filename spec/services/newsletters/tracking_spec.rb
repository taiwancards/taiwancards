# frozen_string_literal: true

require "rails_helper"

RSpec.describe Newsletters::Tracking do
  it "still reads the signed links of letters sent before one-time links" do
    token = described_class.verifier.generate([42, "http://www.example.com/ru/desk"], purpose: described_class::PURPOSE)

    expect(described_class.read(token)).to(eq([42, "http://www.example.com/ru/desk"]))
    expect(described_class.read("#{token}x")).to(be_nil)
  end

  it "keeps the path, query and anchor of a link into the app" do
    expect(described_class.path_of("http://www.example.com/ru/profile?tab=show#mail")).to(
      eq("/ru/profile?tab=show#mail")
    )
    expect(described_class.path_of("http://www.example.com")).to(eq("/"))
  end

  it "lets a letter visit only the app and the static site" do
    allow(Site).to(receive(:url).and_return("https://site.example"))

    expect(described_class.visitable?("https://site.example/ru/")).to(be(true))
    expect(described_class.visitable?("http://www.example.com/ru/desk")).to(be(true))
    expect(described_class.visitable?("https://evil.test/")).to(be(false))
    expect(described_class.visitable?("javascript:alert(1)")).to(be(false))
  end

  it "only treats links to the app itself as ours" do
    expect(described_class.ours?(described_class.absolute("/ru/desk"))).to(be(true))
    expect(described_class.ours?("https://evil.test/ru/desk")).to(be(false))
    expect(described_class.ours?("mailto:hi@example.com")).to(be(false))
  end
end
