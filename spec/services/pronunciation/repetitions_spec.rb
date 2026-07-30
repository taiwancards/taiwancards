# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Repetitions do
  let(:rate) { 22_050 }
  let(:noise) { Random.new(20_260_726) }

  def room(ms) = Array.new((rate * ms / 1000.0).round) { ((noise.rand * 2) - 1) * 0.0005 }

  def spoken(ms, hz: 130.0)
    Array.new((rate * ms / 1000.0).round) do |i|
      t = i.to_f / rate
      0.25 * (Math.sin(2 * Math::PI * hz * t) + (0.5 * Math.sin(2 * Math::PI * 700 * t)))
    end
  end

  def analyzed(samples) = Pronunciation::Acoustic::Features.analyze(samples, rate)

  def spans(samples, expected: 3)
    described_class.split(analyzed(samples), expected: expected)
  end

  def lengths(list) = list.map { |lo, hi| ((hi - lo) * Pronunciation::Acoustic::Features::HOP_MS).round }

  it "splits three repetitions parted by clear pauses" do
    audio = room(300) + spoken(320) + room(260) + spoken(320) + room(260) + spoken(320) + room(300)

    expect(spans(audio).length).to(eq(3))
    expect(lengths(spans(audio))).to(all(be_within(90).of(320)))
  end

  it "copes with only two repetitions" do
    audio = room(300) + spoken(320) + room(280) + spoken(320) + room(300)

    expect(spans(audio).length).to(eq(2))
  end

  it "copes with a single one" do
    audio = room(300) + spoken(320) + room(300)

    expect(spans(audio).length).to(eq(1))
  end

  it "keeps the pauses out of the spans" do
    audio = room(400) + spoken(300) + room(300) + spoken(300) + room(400)
    first, second = spans(audio, expected: 2)

    expect(first[0] * Pronunciation::Acoustic::Features::HOP_MS).to(be > 300)
    expect(second[0] * Pronunciation::Acoustic::Features::HOP_MS).to(be > 950)
  end

  it "never returns more than asked for, merging the closest pair" do
    audio = room(200) +
      spoken(250) +
      room(150) +
      spoken(250) +
      room(150) +
      spoken(250) +
      room(150) +
      spoken(250) +
      room(200)

    expect(spans(audio, expected: 3).length).to(eq(3))
  end

  it "ignores a cough too short to be a syllable" do
    audio = room(300) + spoken(40) + room(250) + spoken(320) + room(300)

    expect(spans(audio).length).to(eq(1))
  end

  it "returns nothing for silence rather than inventing a span" do
    expect(spans(room(900))).to(be_empty)
  end
end
