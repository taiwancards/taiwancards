# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Coach do
  def part(locale, descriptor, level: "red", code: "initial.under_aspirated", vars: {})
    described_class.new(locale:).part(descriptor, 48, level, code, vars)
  end

  let(:aspirated) { {"id" => "initial", "present" => true, "zhuyin" => "ㄎ", "pinyin" => "k", "ipa" => "kʰ"} }

  it "speaks the interface not the one the analyzer was written in" do
    ru = part(:ru, aspirated, vars: {"initial" => "k", "pair" => "g"})
    en = part(:en, aspirated, vars: {"initial" => "k", "pair" => "g"})

    expect(ru["problem"]).to(include("Придыхания"))
    expect(en["problem"]).to(include("aspiration"))
    expect(ru["problem"]).not_to(eq(en["problem"]))
  end

  it "contrasts against the learner's own phonology" do
    expect(part(:ru, aspirated)["cue"]).to(include("выдохом"))
    expect(part(:en, aspirated)["cue"]).to(include("kite"))
  end

  it "stays quiet when the part is already good enough" do
    row = part(:ru, aspirated, level: "green", code: "initial.ok")
    expect(row).not_to(have_key("problem"))
    expect(row["cue"]).to(be_present)
  end

  it "stays quiet when the part could not be measured at all" do
    expect(part(:ru, aspirated, level: "gray", code: "near")).not_to(have_key("problem"))
    expect(part(:ru, {"id" => "medial", "present" => false}, level: "none", code: "near")).not_to(have_key("problem"))
  end

  it "explains a near miss rather than claiming the part was fine" do
    row = part(:ru, aspirated, level: "amber", code: "initial.ok")
    expect(row["problem"]).to(include("не дотягивает"))
  end

  it "has a cue for every initial, medial, rime and tone in both languages" do
    %i[ru en].each do |locale|
      Pronunciation::Parts::ZHUYIN_TO_PINYIN.each_value do |name|
        scope = Pronunciation::Parts::INITIAL_CHARS
          .map { |c| Pronunciation::Parts::ZHUYIN_TO_PINYIN[c] }
          .include?(name) ? "initials" : "rimes"
        expect(I18n.t("pron.#{scope}.#{name}", locale:, default: nil)).to(
          be_present,
          "missing pron.#{scope}.#{name} in #{locale}"
        )
      end

      (1..5).each { |tone| expect(I18n.t("pron.tones.#{tone}", locale:, default: nil)).to(be_present) }
      %w[i u ü].each { |m| expect(I18n.t("pron.medials.#{m}", locale:, default: nil)).to(be_present) }
      expect(I18n.t("pron.rimes.empty", locale:, default: nil)).to(be_present)
    end
  end

  it "has a message and a fix for every error code the analyzer can emit" do
    %i[ru en].each do |locale|
      SyllableSkill::ERROR_CODES.each do |code|
        expect(I18n.t("pron.codes.#{code}", locale:, default: nil)).to(
          be_present,
          "missing pron.codes.#{code} in #{locale}"
        )
        expect(I18n.t("pron.fixes.#{code}", locale:, default: nil)).to(
          be_present,
          "missing pron.fixes.#{code} in #{locale}"
        )
      end
    end
  end

  it "names what was heard instead" do
    coach = described_class.new(locale: :ru)
    expect(coach.confusion("gao1", "gao3")).to(include("тон"))
    expect(coach.confusion("gao1", "kao1")).to(include("kao"))
    expect(coach.confusion("gao1", "gao1")).to(be_nil)
  end
end
