# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::TaiwanPhrases do
  it "loads every scene and pattern" do
    expect(described_class).to(be_available)
    expect(described_class.scenes.length).to(be >= 10)
    expect(described_class.size).to(be >= 100)
  end

  it "keeps scenes in the declared order" do
    positions = described_class.scenes.map(&:position)

    expect(positions).to(eq(positions.sort))
  end

  it "derives zhuyin from the pinyin of every spoken pattern" do
    spoken = described_class.patterns.reject { |pattern| pattern.pinyin.to_s.match?(/\A[…\s]*\z/) }
    missing = spoken.reject(&:zhuyin)

    expect(missing.map(&:id)).to(be_empty)
  end

  it "gives every pattern a scene that exists" do
    unknown = described_class.patterns.map(&:scene).uniq.reject { |id| described_class.scene(id) }

    expect(unknown).to(be_empty)
  end

  it "filters by scene, role and level" do
    staff = described_class.patterns(scene: "store", role: "staff")

    expect(staff).to(all(be_staff))
    expect(described_class.patterns(level: 1)).to(all(satisfy { |pattern| pattern.level <= 1 }))
  end

  it "splits a pattern into literals and slot names" do
    pattern = described_class.patterns.find { |candidate| candidate.slots.any? }

    expect(pattern.parts.flat_map(&:last).compact).to(eq(pattern.slots))
  end

  it "indexes patterns by their linked words and slot options" do
    expect(described_class.for_lexeme("載具").map(&:id)).to(include("store.carrier"))
    expect(described_class.for_lexeme("去冰").map(&:id)).to(include("drinks.answer"))
    expect(described_class.for_lexeme("沒有這個詞")).to(be_empty)
  end

  it "resolves every placeholder to a slot" do
    unresolved = described_class.patterns.flat_map(&:slots).uniq.reject { |name| described_class.slot(name) }

    expect(unresolved).to(be_empty)
  end

  it "separates closed slots, which enumerate their fillers, from open ones" do
    expect(described_class.slot("sugar")).to(be_closed)
    expect(described_class.slot("sugar").options.map(&:text)).to(include("半糖"))

    expect(described_class.slot("飲料")).not_to(be_closed)
    expect(described_class.slot("飲料").name(:en)).to(eq("drink"))
    expect(described_class.slot("飲料").name(:ru)).to(eq("напиток"))
  end

  it "strips placeholders from the literal text used for lexicon lookup" do
    pattern = described_class.patterns.find { |candidate| candidate.id == "self.nationality" }

    expect(pattern.text).to(eq("我是{country}人"))
    expect(pattern.literal).to(eq("我是 人"))
  end

  it "counts the patterns in every scene" do
    expect(described_class.counts["store"]).to(eq(described_class.patterns(scene: "store").length))
    expect(described_class.counts["nonexistent"]).to(eq(0))
  end

  it "records the Taiwanese form to use instead of the China form" do
    pattern = described_class.patterns.find { |candidate| candidate.id == "courtesy.welcome" }

    expect(pattern.avoid["wrong"]).to(eq("不客氣"))
    expect(pattern.avoid["use"]).to(eq("不會"))
  end
end
