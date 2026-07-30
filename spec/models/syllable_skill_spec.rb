# frozen_string_literal: true

require "rails_helper"

RSpec.describe SyllableSkill do
  let(:user) { create(:user) }

  def skill = described_class.claim(user, "qi1")

  it "parses the syllable and tone out of the key once" do
    expect(skill).to(have_attributes(syllable: "qi", tone: 1))
  end

  it "keeps one row however many attempts arrive" do
    5.times { skill.record!(overall: 70, level: "amber") }

    expect(described_class.where(user:).count).to(eq(1))
    expect(skill.n).to(eq(5))
  end

  it "moves the average toward recent attempts without jumping to them" do
    3.times { skill.record!(overall: 40, level: "red") }
    skill.record!(overall: 100, level: "green")

    expect(skill.ewma_overall).to(be > 40)
    expect(skill.ewma_overall).to(be < 100)
  end

  it "counts each level separately and resets the streak on anything but green" do
    skill.record!(overall: 95, level: "green")
    skill.record!(overall: 95, level: "green")
    expect(skill.streak).to(eq(2))

    skill.record!(overall: 50, level: "red")
    expect(skill).to(have_attributes(streak: 0, n_green: 2, n_red: 1))
  end

  it "averages signed deviations so a systematic bias becomes visible" do
    6.times { skill.record!(overall: 60, level: "red", deviations: {"vot_ms" => -2.0}) }

    expect(skill.mean_z("vot_ms")).to(be_within(0.01).of(-2.0))
    expect(skill.systematic.first).to(include("field" => "vot_ms", "z" => -2.0))
  end

  it "does not report a bias when the errors cancel out" do
    3.times { skill.record!(overall: 60, level: "red", deviations: {"vot_ms" => 2.0}) }
    3.times { skill.record!(overall: 60, level: "red", deviations: {"vot_ms" => -2.0}) }

    expect(skill.mean_z("vot_ms")).to(be_within(0.01).of(0.0))
    expect(skill.systematic).to(be_empty)
  end

  it "names the habitual error rather than the last one" do
    4.times { skill.record!(overall: 60, level: "red", codes: ["initial.under_aspirated"]) }
    skill.record!(overall: 60, level: "red", codes: ["vowel.open"])

    expect(skill.habitual_error).to(include("code" => "initial.under_aspirated", "n" => 4))
  end

  it "caps the recent window so the row cannot grow with practice" do
    40.times { |i| skill.record!(overall: i, level: "amber") }

    expect(skill.recent.length).to(eq(described_class::RECENT_SPAN))
    expect(skill.recent.last).to(eq(39))
  end

  it "reads a trend from the two halves of the window" do
    6.times { skill.record!(overall: 40, level: "red") }
    6.times { skill.record!(overall: 90, level: "green") }

    expect(skill.trend).to(be > 0)
  end

  it "records which tone was heard instead" do
    described_class.claim(user, "ma3").record!(overall: 50, level: "red", heard: "ma2")
    described_class.claim(user, "ma3").record!(overall: 50, level: "red", heard: "ma2")

    expect(described_class.find_by(user:, syllable_key: "ma3").tone_confusions).to(eq({2 => 2}))
  end
end
