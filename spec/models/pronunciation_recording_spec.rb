# frozen_string_literal: true

require "rails_helper"

RSpec.describe PronunciationRecording do
  let(:user) { create(:user) }

  def recording(syllables, **attributes)
    described_class.create!(
      user: user,
      text: syllables.map { |s| s["char"] }.join,
      syllable_keys: syllables.map { |s| s["key"] },
      syllables: syllables,
      audio: "bytes",
      **attributes
    )
  end

  let(:one) { [{"key" => "hao3", "index" => 0, "char" => "好"}] }
  let(:two) { one + [{"key" => "shi4", "index" => 1, "char" => "事"}] }

  it "says nothing about a recording nobody has rated" do
    expect(recording(two).label_for(0)).to(be_nil)
  end

  it "says nothing when the native could not decide" do
    row = recording(two)
    row.rate!("unsure")

    expect(row.label_for(0)).to(be_nil)
  end

  it "counts every syllable of an accepted word as accepted" do
    row = recording(two)
    row.rate!("accepted")

    expect([row.label_for(0), row.label_for(1)]).to(eq([true, true]))
  end

  it "blames only the syllables the native marked" do
    row = recording(two)
    row.rate!("rejected", rejected: [1])

    expect([row.label_for(0), row.label_for(1)]).to(eq([true, false]))
  end

  it "blames the only syllable there is when the whole word was rejected" do
    row = recording(one)
    row.rate!("rejected")

    expect(row.label_for(0)).to(be(false))
  end

  it "leaves a longer word unlabelled when the native did not say which syllable was wrong" do
    row = recording(two)
    row.rate!("rejected")

    expect([row.label_for(0), row.label_for(1)]).to(eq([nil, nil]))
  end

  it "forgets which syllables were blamed when the verdict turns to accepted" do
    row = recording(two)
    row.rate!("rejected", rejected: [1])
    row.rate!("accepted")

    expect(row.rejected_indices).to(be_empty)
  end
end
