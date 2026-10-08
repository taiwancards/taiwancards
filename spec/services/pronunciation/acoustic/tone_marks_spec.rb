# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::ToneMarks do
  def falling(points = 16, from: 6.0, to: -6.0)
    Array.new(points) { |i| from + ((to - from) * i / (points - 1.0)) }
  end

  def stat(median, mad = 1.0) = {"median" => median, "mad" => mad, "sigma" => mad}

  def widths = -> (_stat, _field) { 1.0 }

  it "reads the landmarks from the tone nucleus, not from the whole voiced span" do
    curve = Array.new(16) { |i| i < 4 ? 30.0 : 0.0 }
    marks = described_class.of(curve, 0.0)

    expect(marks["mark_onset"]).to(eq(0.0))
    expect(marks["mark_mid"]).to(eq(0.0))
  end

  it "lifts every level landmark by the register and leaves the shape ones alone" do
    plain = described_class.of(falling, 0.0)
    lifted = described_class.of(falling, 4.0)

    described_class::LEVELS.each { |field| expect(lifted[field]).to(be_within(1e-9).of(plain[field] + 4.0)) }
    expect(lifted["mark_late"]).to(be_within(1e-9).of(plain["mark_late"]))
    expect(lifted["mark_curve"]).to(be_within(1e-9).of(plain["mark_curve"]))
  end

  it "keeps the level landmarks out of a row whose register is unknown" do
    row = {"tone_curve" => falling, "f0_register" => nil}
    described_class.stamp!(row)

    expect(row).not_to(include("mark_onset"))
    expect(row["mark_late"]).to(be_present)
  end

  it "charges a syllable spoken too high when the register was heard" do
    template = described_class::LEVELS.index_with { |_| stat(0.0) }.merge(
      "mark_early" => stat(0.0),
      "mark_late" => stat(0.0),
      "mark_curve" => stat(0.0),
      "mark_minpos" => stat(0.5)
    )
    low = {"tone_curve" => Array.new(16, 0.0), "f0_register" => 0.0}
    high = {"tone_curve" => Array.new(16, 0.0), "f0_register" => 8.0}

    on_pitch = described_class.aggregate(described_class.deviations(low, template, widths))
    too_high = described_class.aggregate(described_class.deviations(high, template, widths))

    expect(too_high).to(be > on_pitch + 3.0)
  end

  it "forgives the height when no register was heard, so a single syllable is judged on shape" do
    template = described_class::LEVELS.index_with { |_| stat(0.0) }.merge(
      "mark_early" => stat(0.0),
      "mark_late" => stat(0.0),
      "mark_curve" => stat(0.0),
      "mark_minpos" => stat(0.5)
    )
    shifted = {"tone_curve" => Array.new(16, 8.0)}

    expect(described_class.aggregate(described_class.deviations(shifted, template, widths))).to(be < 0.5)
  end

  it "asks less of the height when it rests on two syllables than on five" do
    template = described_class::LEVELS.index_with { |_| stat(0.0) }.merge(
      "f0_register" => stat(0.0),
      "mark_early" => stat(0.0),
      "mark_late" => stat(0.0),
      "mark_curve" => stat(0.0),
      "mark_minpos" => stat(0.5)
    )
    off = -> (heard) { {"tone_curve" => Array.new(16, 0.0), "f0_register" => 8.0, "n_register" => heard} }

    thin = described_class.aggregate(described_class.deviations(off.call(2), template, widths))
    solid = described_class.aggregate(described_class.deviations(off.call(5), template, widths))

    expect(thin).to(be < solid)
  end

  it "reports the worst landmarks rather than diluting them in the mean" do
    many = [["mark_onset", 0.0]] * 10
    expect(described_class.aggregate(many + [["mark_mid", 9.0]])).to(be > 1.0)
  end
end
