# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::Phonetics do
  before { described_class.reset! }

  after { described_class.reset! }

  it "carries a localised anchor and note on every initial and final" do
    (described_class.initials + described_class.finals).each do |row|
      expect(row["anchor"]).to(be_a(Hash), row["pinyin"])
      expect(row["anchor"].keys).to(match_array(%w[en ru]), row["pinyin"])
      expect(row["anchor"]["ru"]).to(be_present, row["pinyin"])
      expect(row["note"]).to(be_a(Hash), row["pinyin"])
      expect(row["note"].keys).to(match_array(%w[en ru]), row["pinyin"])
    end
  end

  it "explains the aspiration pairs rather than voicing" do
    %w[b p d t g k j q zh ch z c].each do |pinyin|
      row = described_class.initials.find { |item| item["pinyin"] == pinyin }

      expect(row).to(be_present, pinyin)
      expect(row["ru"]).to(match(/придых/), pinyin)
      expect(row["en"]).to(match(/aspirat/i), pinyin)
    end
  end

  it "covers the finals whose spelling hides the sound" do
    covered = described_class.rimes.map { |rime| rime["pinyin"] }

    expect(covered).to(include("-ian", "-ui", "-iu", "-un", "-ong"))
    expect(described_class.rimes).to(be_present)
  end

  it "states the actual sound of -ian rather than the spelling" do
    rime = described_class.rimes.find { |item| item["pinyin"] == "-ian" }

    expect(rime["ipa"]).to(eq("jɛn"))
    expect(rime["ru"]).to(be_present)
    expect(rime["en"]).to(be_present)
  end

  it "writes every rime IPA without brackets, matching the other tables" do
    described_class.rimes.each do |rime|
      expect(rime["ipa"]).not_to(start_with("["), rime["pinyin"])
    end
  end
end
