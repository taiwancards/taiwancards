# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Spectra do
  let(:win) { 64 }
  let(:hop) { 16 }
  let(:samples) { Array.new(400) { |i| Math.sin(2 * Math::PI * 5 * i / 64.0) } }
  let(:window) { DSP::Window.hamming(win) }
  let(:spectrum) { DSP::Spectrum.new(64) }

  def build(length)
    described_class.new(samples:, win:, hop:, window:, spectrum:, length:)
  end

  it "computes nothing until a frame is read" do
    expect(build(10).computed).to(eq(0))
  end

  it "computes only the frames that are read" do
    spectra = build(10)
    spectra[3]
    spectra[7]

    expect(spectra.computed).to(eq(2))
  end

  it "returns the same array on a second read" do
    spectra = build(10)

    expect(spectra[4]).to(be(spectra[4]))
    expect(spectra.computed).to(eq(1))
  end

  it "matches an eager transform of the same frame" do
    frame = DSP::Framing.preemphasis(samples[2 * hop, win], coefficient: described_class::PREEMPHASIS)
    expected = spectrum.power(Array.new(win) { |i| frame[i] * window[i] })

    expect(build(10)[2]).to(eq(expected))
  end

  it "answers nil outside its range" do
    spectra = build(5)

    expect(spectra[-1]).to(be_nil)
    expect(spectra[5]).to(be_nil)
    expect(spectra[nil]).to(be_nil)
  end
end
