# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sound recorded before the syllable" do
  let(:store) { instance_double(Pronunciation::TemplateStore) }
  let(:analyzer) { Pronunciation::Acoustic::Analyzer.new(store) }

  def template(initial: "b", fric: {"median" => 0.0, "sigma" => 10.0})
    {
      "tone" => 4,
      "norm" => "taiwan",
      "structure" => {"initial" => initial, "medial" => "", "nucleus" => "u", "final" => "u", "coda" => ""},
      "vot_ms" => {"median" => 15.0, "sigma" => 8.0},
      "fric_ms" => fric,
      "duration_ms" => {"median" => 280.0, "sigma" => 47.0},
      "voiced_ms" => {"median" => 245.0, "sigma" => 55.0}
    }
  end

  def features(fric:, reliable:, vot: 17.0)
    {"vot_ms" => vot, "vot_reliable" => reliable, "fric_ms" => fric, "duration_ms" => 499.0, "voiced_ms" => 274.0}
  end

  def fields(f, tpl) = analyzer.report(f, tpl).map { |row| row["field"] }

  it "is named in milliseconds once it swallows the start of the syllable" do
    lead = analyzer.lead_in(features(fric: 270.0, reliable: false), template)

    expect(lead["code"]).to(eq("lead_in.noisy"))
    expect(lead.dig("vars", "ms")).to(eq(270))
  end

  it "is not held against a syllable whose release was actually found" do
    expect(analyzer.lead_in(features(fric: 270.0, reliable: true), template)).to(be_nil)
  end

  it "is not invented out of the frication a fricative is supposed to have" do
    sh = template(initial: "sh", fric: {"median" => 140.0, "sigma" => 45.0})

    expect(analyzer.lead_in(features(fric: 150.0, reliable: false), sh)["code"]).not_to(eq("lead_in.noisy"))
  end

  it "is not invented out of the few frames of noise every recording opens with" do
    expect(analyzer.lead_in(features(fric: 20.0, reliable: false), template)["code"]).not_to(eq("lead_in.noisy"))
  end

  it "says the recording opened on the sound when the release was never found" do
    lead = analyzer.lead_in(features(fric: 20.0, reliable: false), template)

    expect(lead["code"]).to(eq("lead_in.clipped"))
    expect(lead.dig("vars", "initial")).to(eq("b"))
  end

  it "stays quiet about an initial the template never asks about" do
    open_rime = template.except("vot_ms")

    expect(analyzer.lead_in(features(fric: 20.0, reliable: false), open_rime)).to(be_nil)
  end

  describe "the worst-features report" do
    it "drops the onset it could not measure through the noise" do
      rows = fields(features(fric: 270.0, reliable: false), template)

      expect(rows).not_to(include("vot_ms", "fric_ms"))
      expect(rows).to(include("duration_ms"))
    end

    it "keeps a frication it can still read when only the release was missed" do
      rows = fields(features(fric: 20.0, reliable: false), template)

      expect(rows).to(include("fric_ms"))
      expect(rows).not_to(include("vot_ms"))
    end

    it "keeps the whole onset when the release was found" do
      expect(fields(features(fric: 270.0, reliable: true), template)).to(include("vot_ms", "fric_ms"))
    end
  end

  describe "what the learner is told" do
    def note(locale)
      backend = Pronunciation::AcousticBackend.new(store: store, locale: locale)
      lead = analyzer.lead_in(features(fric: 270.0, reliable: false), template)
      backend.send(:advisories, [], lead).first["note"]
    end

    it "says how much stray sound there was, in their own language" do
      expect(note(:ru)).to(include("270"))
      expect(note(:ru)).to(include("инициаль"))
      expect(note(:en)).to(include("270"))
      expect(note(:en)).not_to(eq(note(:ru)))
    end
  end
end
