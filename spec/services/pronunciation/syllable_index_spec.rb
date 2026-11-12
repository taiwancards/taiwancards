# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::SyllableIndex do
  def character(text, pinyin) = create(:lexeme, kind: :character, text:, readings: {"pinyin" => pinyin})

  it "stands a syllable on the character with the cleanest reference recording" do
    character("巴", "bā")
    noisy = character("芭", "bā")
    clean = character("笆", "bā")
    lone = character("波", "bō")
    levels = {"芭" => Huayu::MoeAudio::AUDIBLE, "笆" => Huayu::MoeAudio::CLEAN}
    allow(Huayu::MoeAudio).to(receive(:quality)) { |text, **| levels.fetch(text, Huayu::MoeAudio::ABSENT) }

    index = described_class.build

    expect(index.fetch("ba1")).to(eq(clean.id))
    expect(index.fetch("ba1")).not_to(eq(noisy.id))
    expect(index.fetch("bo1")).to(eq(lone.id))
  end

  it "keeps the index until the reference audio changes rather than rebuilding it twice a day" do
    allow(Huayu::MoeAudio).to(receive(:stamp).and_return("41-7-0"))
    allow(Rails.cache).to(receive(:fetch).and_return({}))
    allow(Rails.cache).to(receive(:delete))

    described_class.for
    described_class.refresh

    expect(Rails.cache).to(have_received(:fetch).with("pron:syllable_index:audio:41-7-0").twice)
    expect(Rails.cache).to(have_received(:delete).with("pron:syllable_index:audio:41-7-0"))
  end
end
