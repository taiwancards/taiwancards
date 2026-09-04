# frozen_string_literal: true

require "rails_helper"

RSpec.describe Offline::Freshness do
  let(:section) { Offline::Sections.find("core") }

  it "answers the same stamp for the same pages" do
    expect(described_class.new.digest(section, ["/a"])).to(eq(described_class.new.digest(section, ["/a"])))
  end

  it "answers a different stamp once the page list moves" do
    expect(described_class.new.digest(section, ["/a"])).not_to(eq(described_class.new.digest(section, %w[/a /b])))
  end

  it "keeps the stamps of two packs apart" do
    grammar = Offline::Sections.find("grammar")

    expect(described_class.new.digest(section, ["/a"])).not_to(eq(described_class.new.digest(grammar, ["/a"])))
  end

  it "notices that the templates moved" do
    fresh = described_class.new
    before = fresh.digest(section, ["/a"])
    allow(fresh).to(receive(:templates).and_return("something-else"))

    expect(fresh.digest(section, ["/a"])).not_to(eq(before))
  end
end
