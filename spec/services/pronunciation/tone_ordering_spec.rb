# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Analyzer do
  let(:store) { Pronunciation::TemplateStore.instance }
  let(:analyzer) { described_class.new(store) }

  def rising_template
    %w[ma2 tong2 xue2 ren2 nan2 lai2]
      .filter_map { |key| store.template(key, "taiwan_word") || store.template(key) }
      .find { |t| t.dig("tone_slope", "median").to_f >= 1.0 && t.dig("tone_contour", "center").present? }
  end

  def tone(template, curve, register: nil)
    features = {
      "tone_curve" => curve,
      "tone_range" => curve.max - curve.min,
      "tone_slope" => curve.last - curve.first,
      "duration_ms" => template.dig("duration_ms", "median"),
      "voiced_ms" => template.dig("voiced_ms", "median")
    }
    features["f0_register"] = register if register
    analyzer.score_axes(features, template, "taiwan_word").find { |a| a["id"] == "tone" }
  end

  def rise(size) = Array.new(Pronunciation::Acoustic::Features::TONE_POINTS) { |i| -size / 2.0 + (size * i / 15.0) }

  it "never lets a fall outscore a rise the tone asks for" do
    template = rising_template or skip("no rising template available")

    expect(tone(template, rise(6.0))["score"]).to(be > tone(template, rise(-6.0))["score"])
  end

  it "keeps an exaggerated rise ahead of any fall" do
    template = rising_template or skip("no rising template available")
    worst = tone(template, rise(24.0))["score"]

    [-3.0, -6.0, -12.0].each do |size|
      expect(worst).to(be > tone(template, rise(size))["score"])
    end
  end

  it "still prefers the rise the reference actually has to a bigger one" do
    template = rising_template or skip("no rising template available")
    wanted = template.dig("tone_slope", "median")

    expect(tone(template, rise(wanted))["score"]).to(be > tone(template, rise(24.0))["score"])
  end

  it "leaves a level tone out of the direction question" do
    template = store.template("ma1", "taiwan_word") || store.template("ma1")
    skip("no level template available") if template.nil?
    flat = Array.new(Pronunciation::Acoustic::Features::TONE_POINTS, 0.0)

    expect(analyzer.wrong_direction({"tone_slope" => -3.0}, template)).to(be_nil)
    expect(tone(template, flat)["score"]).to(be > 0)
  end

  it "does not call a small dip against a rise a reversal" do
    template = rising_template or skip("no rising template available")

    expect(analyzer.wrong_direction({"tone_slope" => -1.0}, template)).to(be_nil)
    expect(analyzer.wrong_direction({"tone_slope" => -2.0}, template)).to(eq("tone.falls"))
  end

  def with_register(template, curve, heard)
    features = {
      "tone_curve" => curve,
      "tone_range" => curve.max - curve.min,
      "tone_slope" => curve.last - curve.first,
      "f0_register" => template.dig("f0_register", "median") + 6.0,
      "n_register" => heard
    }
    analyzer.score_axes(features, template, "taiwan_word").find { |a| a["id"] == "tone" }
  end

  it "asks less of the register when it rests on two syllables than on five" do
    template = rising_template or skip("no rising template available")
    skip("no register norm") if template["f0_register"].nil?
    curve = rise(4.0)

    expect(with_register(template, curve, 2)["score"]).to(be > with_register(template, curve, 5)["score"])
  end
end
