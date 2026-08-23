# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Analyzer do
  let(:analyzer) { described_class.new(instance_double(Pronunciation::TemplateStore)) }

  def template(slope)
    {"tone" => 2, "tone_slope" => {"median" => slope, "sigma" => 2.2}}
  end

  def features(slope)
    {"tone_slope" => slope, "tone_range" => 5.0}
  end

  it "names a fall where the reference rises" do
    expect(analyzer.wrong_direction(features(-3.0), template(4.0))).to(eq("tone.falls"))
  end

  it "names a rise where the reference falls" do
    expect(analyzer.wrong_direction(features(3.0), template(-4.0))).to(eq("tone.rises"))
  end

  it "says nothing when the direction agrees" do
    expect(analyzer.wrong_direction(features(3.0), template(4.0))).to(be_nil)
  end

  it "says nothing about a syllable the reference holds level" do
    expect(analyzer.wrong_direction(features(-3.0), template(0.4))).to(be_nil)
  end

  it "says nothing about a contour that barely moves" do
    expect(analyzer.wrong_direction(features(-0.5), template(4.0))).to(be_nil)
  end

  it "no longer claims which tone it heard" do
    expect(described_class.instance_methods).not_to(include(:guess_tone))
  end

  it "carries every code it can emit in both locales" do
    %w[tone.falls tone.rises tone.shape].each do |code|
      %i[ru en].each do |locale|
        expect(I18n.t("pron.codes.#{code}", locale:, default: nil)).to(be_present)
        expect(I18n.t("pron.fixes.#{code}", locale:, default: nil)).to(be_present)
      end
    end
  end
end
