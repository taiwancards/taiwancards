# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Recording do
  def wav(rate, seconds: 0.5)
    body = Array
      .new((rate * seconds).round) { |i| [(Math.sin(2 * Math::PI * 220 * i / rate.to_f) * 12_000).round].pack("s<") }
      .join
    header = ["RIFF", 36 + body.bytesize, "WAVE", "fmt ", 16, 1, 1, rate, rate * 2, 2, 16, "data", body.bytesize].pack(
      "a4Va4a4VvvVVvva4V"
    )
    header + body
  end

  it "brings a browser recording down to the rate the corpus was measured at" do
    _samples, rate = described_class.decode(wav(44_100))
    expect(rate).to(eq(22_050.0))
  end

  it "leaves a recording that already matches alone" do
    samples, rate = described_class.decode(wav(22_050))
    expect(rate).to(eq(22_050.0))
    expect(samples.length).to(eq(11_025))
  end

  it "reads nothing out of an empty upload" do
    expect(described_class.decode("")).to(eq([nil, nil]))
  end
end
