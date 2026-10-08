# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pronunciation::Sync::PAYLOAD covers what the serving code reads" do
  SERVED = {
    "templates" => "the reference templates and their index",
    "templates/index.json" => "the quiz index",
    "thresholds.json" => "Pronunciation::TemplateStore#thresholds",
    "inventory.json" => "Pronunciation::Acoustic::Syllables.inventory",
    "drills.json" => "Pronunciation::Drills",
    "axis_norms.json" => "Pronunciation::AxisNorms",
    "context_norms.json" => "Pronunciation::Acoustic::ContextNorms",
    "junction_norms.json" => "Pronunciation::Acoustic::Junctions"
  }.freeze

  def covered?(name) = Pronunciation::Sync::PAYLOAD.any? { |entry| name == entry || name.start_with?("#{entry}/") }

  SERVED.each do |name, reader|
    it "ships #{name}, which #{reader} reads" do
      expect(covered?(name)).to(be(true))
    end
  end

  it "does not ship what only the corpus builders read" do
    build_only = %w[
      variability.json
      vot_norms.json
      speaker_pitch.json
      style_factor.json
      syllable_quality.json
      contrast_quality.json
      test_split.json
    ]

    expect(build_only.reject { |name| covered?(name) }).to(eq(build_only))
  end

  def served_paths(mod, seen = Set.new)
    return [] unless seen.add?(mod)

    found = mod.constants(false).flat_map do |name|
      value = mod.const_get(name)
      next [] unless value.is_a?(Module)
      next [] if value == Pronunciation::Corpus

      served_paths(value, seen)
    end

    path = mod.const_defined?(:PATH, false) ? mod.const_get(:PATH).to_s : nil
    path&.end_with?(".json") ? found + [path] : found
  end

  it "names a file for every path constant outside the corpus namespace" do
    Rails.application.eager_load!
    paths = served_paths(Pronunciation)

    expect(paths).to(include("axis_norms.json", "context_norms.json"))
    expect(paths.reject { |name| covered?(name) }).to(be_empty)
  end
end
