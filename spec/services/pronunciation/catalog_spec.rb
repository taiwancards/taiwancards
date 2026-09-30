# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Catalog do
  def word(text, pinyin, score:) = create(:lexeme, kind: :word, text:, readings: {"pinyin" => pinyin}, score:)

  def drills_allowing(*keys)
    instance_double(Pronunciation::Drills, available?: true).tap do |drills|
      allow(drills).to(receive(:approves?)) { |key| keys.include?(key) }
    end
  end

  def clips(levels)
    Class.new { define_method(:quality) { |text, zhuyin: nil| levels.fetch(text, Huayu::MoeAudio::ABSENT) } }.new
  end

  it "lists words we grade reliably and can play back, the clean recordings first" do
    noisy = word("看見", "kànjiàn", score: 1.0)
    clean = word("常見", "chángjiàn", score: 5.0)
    word("罕見", "hǎnjiàn", score: 2.0)
    word("少見", "shǎojiàn", score: 3.0)
    audio = clips(
      "看見" => Huayu::MoeAudio::AUDIBLE,
      "常見" => Huayu::MoeAudio::CLEAN,
      "罕見" => Huayu::MoeAudio::CLEAN
    )

    entries = described_class.new(drills: drills_allowing("kan4", "chang2", "jian4", "shao3"), audio:).entries

    expect(entries.pluck(:id)).to(eq([clean.id, noisy.id]))
    expect(entries.first).to(
      include(audio: Huayu::MoeAudio::CLEAN, features: include("i:ㄔ", "t:2", "f:ㄤ", "m:ㄧ"))
    )
  end

  it "is empty until the drills say which syllables can be graded" do
    word("常見", "chángjiàn", score: 1.0)
    drills = instance_double(Pronunciation::Drills, available?: false)

    expect(described_class.new(drills:, audio: clips("常見" => Huayu::MoeAudio::CLEAN)).entries).to(be_empty)
  end
end
