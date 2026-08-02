# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pronunciation" do
  let(:headers) do
    {
      "Host" => "rusty-undefaulting-marilou.ngrok-free.app",
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36"
    }
  end

  def warm_up!
    VoiceProfile.create!(user: @authenticated_user, f3_ref: 2900, calibrated_at: Time.current)
  end

  it "builds a practice card with per-syllable expected tones" do
    word = create(
      :lexeme,
      text: "教堂",
      readings: {"pinyin" => "jiàotáng", "zhuyin" => "ㄐㄧㄠˋ ㄊㄤˊ"},
      meanings: {"en" => "church"}
    )

    warm_up!
    get("/pronunciation", params: {lexeme_id: word.id}, headers:)
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("data-controller=\"pronunciation\""))
    expect(response.body).to(include("教堂"))
    expect(response.body).to(include("data-pronunciation-url-value=\"/pronunciation\""))
  end

  it "renders one tile per syllable and no unparsed template" do
    word = create(
      :lexeme,
      kind: :word,
      text: "教堂",
      readings: {"pinyin" => "jiàotáng", "zhuyin" => "ㄐㄧㄠˋ ㄊㄤˊ"}
    )

    warm_up!
    get("/pronunciation", params: {lexeme_id: word.id}, headers:)

    expect(response.body.scan(/data-pronunciation-target="syllable"/).length).to(eq(2))
    expect(response.body.scan(/data-role="parts"/).length).to(eq(2))
    expect(response.body).not_to(include("- @syllables"))
  end

  it "shows pinyin alongside zhuyin and lets the global toggle hide it" do
    word = create(
      :lexeme,
      kind: :word,
      text: "教堂",
      readings: {"pinyin" => "jiàotáng", "zhuyin" => "ㄐㄧㄠˋ ㄊㄤˊ"}
    )

    warm_up!
    get("/pronunciation", params: {lexeme_id: word.id}, headers:)

    expect(response.body).to(include("jiào"))
    expect(response.body.scan(/class="pinyin[^"]*"/).length).to(be >= 2)
  end

  it "keeps the drill sections down to two rows" do
    warm_up!
    get("/pronunciation", headers:)

    tabs = response.body.scan(/data-drill-groups-target="tab"/).length
    expect(tabs).to(be <= 4)
    expect(response.body.scan(/data-drill-groups-target="group"/).length).to(eq(tabs))
  end

  it "sends a voice without a profile to the warm-up first" do
    create(:lexeme, kind: :word, text: "高", readings: {"pinyin" => "gāo"})

    get("/pronunciation", headers:)
    expect(response).to(redirect_to(pronunciation_warmup_path))

    warm_up!

    get("/pronunciation", headers:)
    expect(response).to(have_http_status(:ok))
    expect(response.body).not_to(include(I18n.t("pron.ui.warmup_title")))
  end

  describe "acoustic grading" do
    let(:store) { Pronunciation::TemplateStore.instance }

    it "reports health from the template store" do
      get("/pronunciation/health", headers:)

      expect(response).to(have_http_status(:ok))
      body = JSON.parse(response.body)
      expect(body).to(include("backend" => "acoustic"))
      expect(body).to(have_key("ok"))
    end

    it "returns 404 for a syllable with no template" do
      get("/pronunciation/templates/zzz9", headers:)
      expect(response).to(have_http_status(:not_found))
    end

    it "records one attempt per syllable when grading succeeds" do
      word = create(:lexeme, kind: :word, text: "教堂", readings: {"pinyin" => "jiàotáng"})
      audio = Rack::Test::UploadedFile.new(StringIO.new("fake-wav"), "audio/wav", original_filename: "a.wav")
      expected = [
        {"char" => "教", "pinyin" => "jiào", "tone" => 4, "key" => "jiao4"},
        {"char" => "堂", "pinyin" => "táng", "tone" => 2, "key" => "tang2"}
      ].to_json

      graded = {
        "syllables" => [
          {
            "key" => "jiao4",
            "overall" => 91,
            "level" => "green",
            "cells" => {"tone" => {"score" => 90}},
            "best_match" => "jiao4",
            "rejected" => false
          },
          {
            "key" => "tang2",
            "overall" => 54,
            "level" => "red",
            "cells" => {"tone" => {"score" => 40}},
            "best_match" => "tang1",
            "rejected" => true
          }
        ],
        "overall" => 72
      }
      allow_any_instance_of(Pronunciation::AcousticBackend).to(receive(:grade).and_return(graded))

      expect do
        post("/pronunciation/grade", params: {audio:, expected:, text: "教堂", lexeme_id: word.id}, headers:)
      end
        .to(change(PronunciationAttempt, :count).by(2))

      expect(response).to(have_http_status(:ok))
      first, second = PronunciationAttempt.order(:syllable_index).last(2)
      expect(first.syllable_key).to(eq("jiao4"))
      expect(first.ok).to(be(true))
      expect(second.score_tone).to(eq(40))
      expect(second.rejected).to(be(true))
      expect(second.best_match).to(eq("tang1"))
    end

    it "excludes tone from the score in a segmental drill" do
      word = create(:lexeme, kind: :word, text: "高", readings: {"pinyin" => "gāo"})
      audio = Rack::Test::UploadedFile.new(StringIO.new("fake-wav"), "audio/wav", original_filename: "a.wav")

      captured = nil
      allow(Pronunciation::AcousticBackend).to(receive(:new)) do |**kwargs|
        captured = kwargs[:tonal]
        instance_double(Pronunciation::AcousticBackend, grade: {"syllables" => []})
      end

      post(
        "/pronunciation/grade",
        params: {audio:, expected: "[]", text: "高", lexeme_id: word.id, tonal: "false"},
        headers:
      )
      expect(captured).to(be(false))
    end

    it "answers offline when no templates are installed" do
      word = create(:lexeme, kind: :word, text: "教堂", readings: {"pinyin" => "jiàotáng"})
      audio = Rack::Test::UploadedFile.new(StringIO.new("fake-wav"), "audio/wav", original_filename: "a.wav")
      allow_any_instance_of(Pronunciation::AcousticBackend).to(receive(:grade).and_return(nil))

      post("/pronunciation/grade", params: {audio:, expected: "[]", text: "教堂", lexeme_id: word.id}, headers:)
      expect(response).to(have_http_status(:service_unavailable))
    end
  end

  describe Huayu::PronunciationTarget do
    it "derives per-syllable char, pinyin, tone and template key" do
      word = create(:lexeme, text: "教堂", readings: {"pinyin" => "jiàotáng"})
      syllables = described_class.new(word).syllables
      expect(syllables).to(
        eq(
          [
            {
              "char" => "教",
              "pinyin" => "jiào",
              "zhuyin" => "ㄐㄧㄠˋ",
              "tone" => 4,
              "base_tone" => 4,
              "key" => "jiao4"
            },
            {
              "char" => "堂",
              "pinyin" => "táng",
              "zhuyin" => "ㄊㄤˊ",
              "tone" => 2,
              "base_tone" => 2,
              "key" => "tang2"
            }
          ]
        )
      )
    end
  end
end
