# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Keeper do
  let(:owner) { create(:user, restricted_content: true) }
  let(:learner) { create(:user) }

  def result(*keys)
    {
      "syllables" => keys.each_with_index.map { |key, index|
        {
          "key" => key,
          "index" => index,
          "char" => "字",
          "level" => "green",
          "overall" => 90,
          "cells" => {"tone" => {"score" => 88}, "final" => {"score" => 91}}
        }
      }
    }
  end

  it "keeps a recording for the owner" do
    described_class.new(owner).keep(audio: "bytes", text: "好事", result: result("hao3", "shi4"))

    expect(PronunciationRecording.last).to(have_attributes(syllable_keys: %w[hao3 shi4], verdict: "unrated"))
  end

  it "keeps the scores the engine gave at the time, so the rating can be checked against them" do
    described_class.new(owner).keep(audio: "bytes", text: "好", result: result("hao3"))

    expect(PronunciationRecording.last.syllables.first).to(
      include("overall" => 90, "cells" => {"tone" => 88, "final" => 91})
    )
  end

  it "keeps nothing for an ordinary learner" do
    described_class.new(learner).keep(audio: "bytes", text: "好", result: result("hao3"))

    expect(PronunciationRecording.count).to(be_zero)
  end

  it "keeps nothing when nobody is signed in" do
    described_class.new(nil).keep(audio: "bytes", text: "好", result: result("hao3"))

    expect(PronunciationRecording.count).to(be_zero)
  end

  it "stops collecting a syllable once it has enough samples" do
    (described_class::PER_KEY + 3).times do
      described_class.new(owner).keep(audio: "bytes", text: "好", result: result("hao3"))
    end

    expect(PronunciationRecording.count).to(eq(described_class::PER_KEY))
  end

  it "still keeps a word when one of its syllables is new" do
    described_class::PER_KEY.times do
      described_class.new(owner).keep(audio: "bytes", text: "好", result: result("hao3"))
    end

    described_class.new(owner).keep(audio: "bytes", text: "好事", result: result("hao3", "shi4"))

    expect(PronunciationRecording.count).to(eq(described_class::PER_KEY + 1))
  end

  it "refuses audio too large to be one attempt" do
    described_class.new(owner).keep(audio: "x" * (described_class::MAX_BYTES + 1), text: "好", result: result("hao3"))

    expect(PronunciationRecording.count).to(be_zero)
  end

  it "keeps nothing when the engine recognised no syllable" do
    described_class.new(owner).keep(audio: "bytes", text: "好", result: {"syllables" => []})

    expect(PronunciationRecording.count).to(be_zero)
  end

  it "stops collecting while a pile of recordings is still waiting to be rated" do
    allow(PronunciationRecording).to(
      receive(:unrated).and_return(instance_double(ActiveRecord::Relation, count: described_class::UNRATED_ROOM))
    )

    expect(described_class.new(owner).collecting?).to(be(false))
  end
end
