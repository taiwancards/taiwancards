# frozen_string_literal: true

require "rails_helper"

RSpec.describe "What the pronunciation analyser measures" do
  let(:store) { instance_double(Pronunciation::TemplateStore) }
  let(:analyzer) { Pronunciation::Acoustic::Analyzer.new(store) }

  def template(structure:, **extra)
    {
      "tone" => 1,
      "norm" => "taiwan",
      "structure" => structure,
      "f1_ratio" => {"median" => 0.25, "sigma" => 0.05},
      "f2_ratio" => {"median" => 0.45, "sigma" => 0.07}
    }.merge(extra)
  end

  def features(**extra)
    {"f1_ratio" => 0.25, "f2_ratio" => 0.45, "voiced_ms" => 215.0, "duration_ms" => 530.0}.merge(
      extra.transform_keys(&:to_s)
    )
  end

  describe "a tone with almost no voicing behind it" do
    let(:falling) do
      template(
        structure: {
          "initial" => "h",
          "medial" => "",
          "nucleus" => "a",
          "final" => "ao",
          "coda" => "o",
          "nasal_coda" => false
        }
      )
        .merge(
          "tone" => 4,
          "tone_contour" => {"center" => Array.new(16) { |i| 4.0 - (0.5 * i) }, "sigma" => Array.new(16, 0.8)},
          "tone_range" => {"median" => 7.5, "sigma" => 2.0},
          "tone_slope" => {"median" => -7.5, "sigma" => 2.5}
        )
    end

    def curve(range)
      Array.new(16) { |i| range * (0.5 - (i / 15.0)) }
    end

    it "is left unscored rather than given a number the signal cannot support" do
      f = features(voiced_ms: 20.0).merge("tone_curve" => curve(0.0), "tone_range" => 0.0, "tone_slope" => 0.0)

      expect(analyzer.score_axes(f, falling, "taiwan").find { |a| a["id"] == "tone" }).to(be_nil)
    end

    it "is scored once there is enough voicing" do
      f = features(voiced_ms: 200.0).merge("tone_curve" => curve(7.5), "tone_range" => 7.5, "tone_slope" => -7.5)

      expect(analyzer.score_axes(f, falling, "taiwan").find { |a| a["id"] == "tone" }).to(be_present)
    end
  end

  describe "a diphthong offglide" do
    let(:structure) do
      {"initial" => "g", "medial" => "", "nucleus" => "a", "final" => "ao", "coda" => "o", "nasal_coda" => false}
    end

    it "is never diagnosed as a nasal coda" do
      axes = analyzer.score_axes(
        features(nasal_ratio_tail: 0.5),
        template(:structure => structure, "nasal_ratio_tail" => {"median" => 0.1, "sigma" => 0.05}),
        "taiwan"
      )

      expect(axes.map { |a| a["id"] }).not_to(include("coda"))
      expect(axes.map { |a| a["code"] }).to(all(satisfy { |code| !code.to_s.start_with?("coda.") }))
    end
  end

  describe "a real nasal coda" do
    let(:structure) do
      {"initial" => "b", "medial" => "", "nucleus" => "a", "final" => "an", "coda" => "n", "nasal_coda" => true}
    end

    it "is still measured" do
      axes = analyzer.score_axes(
        features("nasal_ratio_tail" => 0.5),
        template(:structure => structure, "nasal_ratio_tail" => {"median" => 0.1, "sigma" => 0.05}),
        "taiwan"
      )

      expect(axes.map { |a| a["id"] }).to(include("coda"))
    end
  end

  describe "syllable length" do
    let(:structure) { {"initial" => "s", "medial" => "", "nucleus" => "u", "final" => "u", "coda" => ""} }
    let(:tpl) do
      template(
        :structure => structure,
        "voiced_ms" => {"median" => 215.0, "sigma" => 35.0},
        "duration_ms" => {"median" => 535.0, "sigma" => 42.0}
      )
    end

    it "is judged on the voiced part, not on everything above the noise floor" do
      quiet = analyzer.score_axes(features(voiced_ms: 215.0, duration_ms: 530.0), tpl, "taiwan")
      noisy = analyzer.score_axes(features(voiced_ms: 215.0, duration_ms: 1630.0), tpl, "taiwan")

      duration = -> (axes) { axes.find { |a| a["id"] == "duration" } }
      expect(duration.(quiet)["code"]).to(eq("duration.ok"))
      expect(duration.(noisy)["code"]).to(eq("duration.ok"))
      expect(duration.(noisy)["score"]).to(eq(duration.(quiet)["score"]))
    end

    it "says nothing about a drawn-out vowel: speaking slowly is not an error" do
      axes = analyzer.score_axes(features(voiced_ms: 900.0), tpl, "taiwan")

      expect(axes.find { |a| a["id"] == "duration" }["code"]).to(eq("duration.ok"))
    end

    it "never lets duration reach the overall score" do
      axes = analyzer.score_axes(features(voiced_ms: 900.0), tpl, "taiwan")
      duration = axes.find { |a| a["id"] == "duration" }

      expect(duration["part"]).to(be_nil)
      expect(analyzer.part_scores(axes).map { |p| p["id"] }).not_to(include("duration"))
    end
  end

  describe "the 'it sounded like' headline" do
    let(:backend) { Pronunciation::AcousticBackend.new(store: store, locale: :ru) }

    def parts(tone:, initial: 99, final: 99)
      [
        {"id" => "initial", "score" => initial},
        {"id" => "final", "score" => final},
        {"id" => "tone", "score" => tone}
      ]
    end

    it "keeps quiet about a rival tone when the tone itself scored green" do
      expect(backend.send(:confusion, "gao1", "gao3", parts(tone: 96))).to(be_nil)
    end

    it "still names the rival tone when the tone really is off" do
      expect(backend.send(:confusion, "gao1", "gao3", parts(tone: 30))).to(be_present)
    end

    it "keeps quiet about a rival syllable when every sound scored green" do
      expect(backend.send(:confusion, "gao1", "kao1", parts(tone: 40))).to(be_nil)
    end

    it "names the rival syllable when a sound is genuinely weak" do
      expect(backend.send(:confusion, "gao1", "kao1", parts(tone: 96, initial: 30))).to(be_present)
    end
  end

  describe "finding where the speech is" do
    def energies(noise_db:, speech_db: -14.0, silence: 0)
      Array.new(silence, -120.0) + Array.new(20, noise_db) + Array.new(15, speech_db) + Array.new(20, noise_db)
    end

    def extent(energy)
      low, high = Pronunciation::Acoustic::Features.speech_bounds({energy:, n: energy.length})
      high - low + 1
    end

    it "finds the same speech however loud the room is" do
      quiet = extent(energies(noise_db: -80.0))
      room = extent(energies(noise_db: -45.0))
      loud = extent(energies(noise_db: -35.0))

      expect(room).to(eq(quiet))
      expect(loud).to(eq(quiet))
    end

    it "ignores digital silence when estimating the background" do
      with_silence = extent(energies(noise_db: -45.0, silence: 30))
      without = extent(energies(noise_db: -45.0))

      expect(with_silence).to(eq(without))
    end
  end
end
