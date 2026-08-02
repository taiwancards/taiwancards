# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tracking a voice" do
  let(:rate) { 22_050 }

  def resonate(samples, hz, bandwidth)
    r = Math.exp(-Math::PI * bandwidth / rate)
    c = 2 * r * Math.cos(2 * Math::PI * hz / rate)
    d = -(r ** 2)
    y1 = 0.0
    y2 = 0.0
    samples.map do |x|
      y = x + (c * y1) + (d * y2)
      y2 = y1
      y1 = y
      y
    end
  end

  def vowel(ms, f0:, formants:)
    length = (rate * ms / 1000.0).round
    period = (rate / f0).round
    wave = formants.reduce(Array.new(length) { |i| (i % period).zero? ? 1.0 : 0.0 }) do |acc, (hz, bandwidth)|
      resonate(acc, hz, bandwidth)
    end

    peak = wave.map(&:abs).max
    wave.map { |v| 0.5 * v / peak }
  end

  def room(ms, level: 0.0005)
    Array.new((rate * ms / 1000.0).round) { ((rand * 2) - 1) * level }
  end

  def measure(samples, **options)
    an = Pronunciation::Acoustic::Features.analyze(samples, rate)
    span = Pronunciation::Acoustic::Features.speech_bounds(an)
    Pronunciation::Acoustic::Features.extract(an, span, **options)
  end

  describe "a close vowel from a low voice" do
    let(:close) { room(200) + vowel(400, f0: 130, formants: [[300, 60], [2200, 110], [3700, 170]]) + room(200) }

    it "keeps the first formant where it was spoken" do
      features = measure(close)

      expect(features["f1_mid"]).to(be_within(120).of(300))
      expect(features["f2_mid"]).to(be_within(200).of(2200))
    end

    it "keeps the formant ratios the templates are built on" do
      features = measure(close)

      expect(features["f1_ratio"]).to(be_within(0.05).of(300.0 / 3700))
    end
  end

  describe "an octave the pitch tracker dropped" do
    let(:track) { [200.0, 210.0, 205.0, 195.0, 190.0] }

    def curve(values, reference)
      Pronunciation::Acoustic::Features.octave_aligned(values, reference)
    end

    it "is lifted back to the speaker's own range" do
      expect(curve(track.map { |hz| hz / 2 }, 200.0)).to(eq(track))
    end

    it "leaves a track that already sits in range alone" do
      expect(curve(track, 200.0)).to(eq(track))
    end

    it "leaves the shape of the contour untouched" do
      halved = curve(track.map { |hz| hz / 2 }, 200.0)
      ratios = halved.each_cons(2).map { |a, b| b / a }

      expect(ratios).to(eq(track.each_cons(2).map { |a, b| b / a }))
    end

    it "does nothing at all without a calibrated speaker to compare against" do
      quiet = track.map { |hz| hz / 2 }

      expect(curve(quiet, nil)).to(eq(quiet))
    end

    it "does not touch unvoiced frames" do
      expect(curve([0.0, 100.0, 0.0, 105.0, 98.0, 0.0], 200.0)).to(eq([0.0, 200.0, 0.0, 210.0, 196.0, 0.0]))
    end
  end
end
