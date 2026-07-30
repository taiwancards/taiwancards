# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::ToneStats do
  let(:user) { create(:user) }

  def practice(key, level: "green", heard: nil, parts: {})
    SyllableSkill.claim(user, key).record!(overall: 80, level:, parts:, heard: heard || key)
  end

  it "counts tone confusions and per-tone accuracy for the user" do
    practice("xue2", level: "red", heard: "xue3")
    practice("xue2", level: "red", heard: "xue3")
    practice("jiao4", level: "red", heard: "jiao1")
    practice("xue2", level: "green")

    stats = described_class.new(user)
    expect(stats.confusions.first).to(eq([[2, 3], 2]))
    expect(stats.accuracy_by_tone[2]).to(eq({total: 3, correct: 1}))
  end

  it "groups accuracy by initial" do
    practice("xue2")
    practice("xue3")
    practice("jiao4", level: "red", heard: "qiao4")

    rows = described_class.new(user).accuracy_by_initial
    expect(rows.find { |r| r[:initial] == "x" }).to(eq({initial: "x", total: 2, correct: 2}))
    expect(rows.find { |r| r[:initial] == "j" }).to(eq({initial: "j", total: 1, correct: 0}))
  end

  it "reports the weakest components once there is enough data" do
    25.times { practice("xue2", parts: {"tone" => 40, "final" => 90}) }

    weakest = described_class.new(user).weakest_components
    expect(weakest.first[:component]).to(eq("tone"))
    expect(weakest.first[:average]).to(eq(40.0))
  end

  it "does not read other users' skills" do
    practice("xue1", level: "red", heard: "xue4")
    expect(described_class.new(create(:user)).confusions).to(be_empty)
  end

  it "keeps one row per syllable however many attempts are made" do
    30.times { practice("xue2") }

    expect(SyllableSkill.where(user:).count).to(eq(1))
    expect(SyllableSkill.find_by(user:, syllable_key: "xue2").n).to(eq(30))
  end
end
