# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Voice warm-up" do
  def wav
    Rack::Test::UploadedFile.new(StringIO.new("fake-wav"), "audio/wav", original_filename: "w.wav")
  end

  it "offers prompts in the interface language" do
    get("/pronunciation/warmup")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("data-controller=\"warmup\""))
    expect(response.body).to(include("ee — ah — oo"))
  end

  it "explains why the warm-up exists rather than just asking for a recording" do
    get("/pronunciation/warmup")
    expect(response.body).to(include(I18n.t("pron.ui.warmup_why")))
  end

  it "creates the profile on first visit and keeps it on the next" do
    expect { get("/pronunciation/warmup") }.to(change(VoiceProfile, :count).by(1))
    expect { get("/pronunciation/warmup") }.not_to(change(VoiceProfile, :count))
  end

  it "rejects a recording it cannot measure instead of storing noise" do
    audio = Rack::Test::UploadedFile.new(StringIO.new("not-a-wav"), "audio/wav", original_filename: "a.wav")

    post("/pronunciation/warmup", params: {audio:, kind: "sustained"})

    expect(response).to(have_http_status(:ok))
    expect(JSON.parse(response.body)).to(include("ok" => false))
    expect(VoiceProfile.where.not(calibrated_at: nil)).to(be_empty)
  end

  it "stores the measured pitch range and reports it back" do
    profile = VoiceProfile.find_or_create_by!(user: Current.user)
    analysis = {f0_voiced: Array.new(400) { 120.0 }, f3_median: 2900.0, f1_median: 500.0, f2_median: 1500.0}

    result = Pronunciation::Calibration.ingest(profile, analysis, kind: "sustained", locale: "en")

    expect(result[:ok]).to(be(true))
    expect(profile.reload).to(be_calibrated)
    expect(profile.f0_median).to(be_within(6).of(120))
  end

  it "lets the learner start over" do
    get("/pronunciation/warmup")
    expect { delete("/pronunciation/warmup") }.to(change(VoiceProfile, :count).by(-1))
    expect(response).to(redirect_to(pronunciation_warmup_path))
  end

  it "grades without a profile" do
    word = create(:lexeme, kind: :word, text: "高", readings: {"pinyin" => "gāo"})
    audio = Rack::Test::UploadedFile.new(StringIO.new("fake"), "audio/wav", original_filename: "a.wav")

    expect(VoiceProfile.count).to(eq(0))
    post("/pronunciation/grade", params: {audio:, expected: "[]", text: "高", lexeme_id: word.id})

    expect(response.status).to(be_in([200, 422, 503]))
  end

  describe "the tone steps" do
    it "asks for a real syllable of every tone" do
      get("/pronunciation/warmup")

      expect(response.body).to(include("媽", "麻", "馬", "罵"))
    end

    it "spells out the reading so the character is not a guess" do
      get("/pronunciation/warmup")

      expect(response.body).to(include("ㄇㄚˇ"))
      expect(response.body).to(include("mǎ"))
    end

    it "explains each tone in the language of the interface" do
      get("/pronunciation/warmup")

      expect(response.body).to(include("questioning"))
    end

    it "files the recording under the tone it was asked for" do
      profile = VoiceProfile.create!(user: Current.user)
      analysis = {f0_voiced: Array.new(40, 220.0)}
      allow_any_instance_of(Pronunciation::WarmupAnalysis).to(receive(:call).and_return(analysis))

      post("/pronunciation/warmup", params: {audio: wav, kind: "tone", tone: "1"})

      expect(profile.reload.f0_by_tone["1"].to_a.sum).to(be_positive)
    end

    it "replaces the tone rather than piling retries on top of a bad one" do
      profile = VoiceProfile.create!(user: Current.user)
      allow_any_instance_of(Pronunciation::WarmupAnalysis).to(
        receive(:call).and_return({f0_voiced: Array.new(60, 230.0)})
      )
      post("/pronunciation/warmup", params: {audio: wav, kind: "tone", tone: "1"})
      expect(profile.reload.tone_anchor(1)).to(be_within(12).of(230))

      allow_any_instance_of(Pronunciation::WarmupAnalysis).to(
        receive(:call).and_return({f0_voiced: Array.new(60, 140.0)})
      )
      post("/pronunciation/warmup", params: {audio: wav, kind: "tone", tone: "1"})

      expect(profile.reload.tone_anchor(1)).to(be_within(12).of(140))
    end

    it "flags anchors that collapsed onto one pitch" do
      profile = VoiceProfile.create!(user: Current.user)
      profile.observe_f0!(Array.new(60, 200.0), tone: 1)
      profile.observe_f0!(Array.new(60, 197.0), tone: 3)

      expect(profile.anchors_sane?).to(be(false))
    end

    it "accepts anchors a real speaker would produce" do
      profile = VoiceProfile.create!(user: Current.user)
      profile.observe_f0!(Array.new(60, 267.0), tone: 1)
      profile.observe_f0!(Array.new(60, 140.0), tone: 3)

      expect(profile.anchors_sane?).to(be(true))
    end

    it "halves a syllable the tracker doubled, and leaves a genuinely low note alone" do
      profile = VoiceProfile.create!(user: Current.user)
      profile.observe_f0!(Array.new(60, 190.0), tone: 1)
      profile.observe_f0!(Array.new(60, 100.0), tone: 3)

      expect(profile.octave_corrected(260.0)).to(be_within(6).of(130))
      expect(profile.octave_corrected(90.0)).to(be_within(1).of(90))
      expect(profile.octave_corrected(110.0)).to(be_within(1).of(110))
    end

    it "does not let a doubled attempt drag the profile upwards" do
      profile = VoiceProfile.create!(user: Current.user)
      profile.observe_f0!(Array.new(60, 190.0), tone: 1)
      profile.observe_f0!(Array.new(60, 100.0), tone: 3)
      before = profile.reference_hz

      Pronunciation::Calibration.refine!(profile, f0_values: Array.new(60, 280.0), tone: 4, score: 90)

      expect(profile.reference_hz).to(be_within(0.15 * before).of(before))
    end

    it "keeps a tone-free step out of the per-tone histogram" do
      profile = VoiceProfile.create!(user: Current.user)
      analysis = {f0_voiced: Array.new(40, 220.0)}
      allow_any_instance_of(Pronunciation::WarmupAnalysis).to(receive(:call).and_return(analysis))

      post("/pronunciation/warmup", params: {audio: wav, kind: "sustained"})

      expect(profile.reload.f0_by_tone).to(be_empty)
    end

    it "reads a reference off one recording rather than waiting for hundreds of frames" do
      profile = VoiceProfile.create!(user: Current.user)
      analysis = {f0_voiced: Array.new(40, 220.0)}
      allow_any_instance_of(Pronunciation::WarmupAnalysis).to(receive(:call).and_return(analysis))

      post("/pronunciation/warmup", params: {audio: wav, kind: "tone", tone: "1"})

      expect(profile.reload.tone_anchor(1)).to(be_within(6).of(220))
    end
  end
end
