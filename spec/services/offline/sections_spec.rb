# frozen_string_literal: true

require "rails_helper"

RSpec.describe Offline::Sections do
  it "lists a pack for every TOCFL level" do
    levels = described_class.levels.map(&:level)

    expect(levels).to(eq(SentenceProfile::TOCFL_LEVELS))
  end

  it "puts every pack in a known group" do
    expect(described_class.all.map(&:group).uniq - described_class::GROUPS).to(be_empty)
  end

  it "keeps the ids unique" do
    expect(described_class.ids.uniq).to(eq(described_class.ids))
  end

  it "finds a pack by its id" do
    expect(described_class.find("grammar").group).to(eq("texts"))
  end

  it "names the levelled packs after their level" do
    expect(described_class.find("tocfl-a1").level).to(eq("A1"))
  end
end
