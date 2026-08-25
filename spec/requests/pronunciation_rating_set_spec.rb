# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Collecting a rating set from real attempts", :aggregate_failures do
  let(:data_path) { Rails.root.join("data/pronunciation") }
  let(:owner) { create(:user, restricted_content: true) }
  let!(:lexeme) { create(:lexeme, kind: :word, text: "馬", readings: {"pinyin" => "mǎ"}) }

  before do
    skip("data/pronunciation not checked out") unless File.directory?(data_path.join("templates/taiwan"))

    ENV["PRONUNCIATION_DATA_PATH"] = data_path.to_s
    Pronunciation::TemplateStore.reset!
    Pronunciation::Acoustic::Syllables.load!
    sign_in(owner)
  end

  after do
    ENV.delete("PRONUNCIATION_DATA_PATH")
    Pronunciation::TemplateStore.reset!
  end

  def synthetic_wav(ms: 420, rate: 16_000)
    samples = (ms * rate / 1000).to_i
    phase = 0.0
    body = (0...samples).map { |i|
      t = i.to_f / rate
      f0 = 125.0 * (2 ** ((-2.0 * t / (ms / 1000.0)) / 12))
      phase += 2 * Math::PI * f0 / rate
      value = [[1, 1.0], [2, 0.6], [3, 0.4], [5, 0.5], [7, 0.35], [11, 0.2]].sum { |(harmonic, amp)|
        amp * Math.sin(phase * harmonic)
      }
      envelope = [1.0, t / 0.03, ((ms / 1000.0) - t) / 0.05].min
      [(value * envelope * 0.09 * 32_767).to_i, 32_767].min.clamp(-32_767, 32_767)
    }

    header = "RIFF" +
      [36 + (body.length * 2)].pack("V") +
      "WAVEfmt " +
      [16, 1, 1, rate, rate * 2, 2, 16].pack("VvvVVvv") +
      "data" +
      [body.length * 2].pack("V")
    (header + body.pack("s<*")).b
  end

  def attempt
    post(
      "/pronunciation/grade",
      params: {
        audio: Rack::Test::UploadedFile.new(StringIO.new(synthetic_wav), "audio/wav", true, original_filename: "take.wav"),
        text: "馬",
        lexeme_id: lexeme.id,
        expected: [{"char" => "馬", "pinyin" => "ma3", "tone" => 3, "key" => "ma3", "zhuyin" => "ㄇㄚˇ"}].to_json
      }
    )
  end

  it "keeps the recording the owner just graded, with the audio it can be re-measured from" do
    attempt

    expect(response).to(have_http_status(:ok))
    expect(PronunciationRecording.last).to(have_attributes(syllable_keys: %w[ma3], verdict: "unrated"))
    expect(PronunciationRecording.last.audio.bytesize).to(eq(synthetic_wav.bytesize))
  end

  it "still grades the attempt when the recording cannot be kept" do
    allow(Pronunciation::Keeper).to(receive(:new).and_raise(ActiveRecord::StatementInvalid))
    attempt

    expect(response).to(have_http_status(:ok))
    expect(response.parsed_body["syllables"].first["key"]).to(eq("ma3"))
  end

  it "measures the engine against the native's verdict, from the stored audio" do
    attempt
    PronunciationRecording.last.rate!("accepted")
    attempt
    PronunciationRecording.last.rate!("rejected")

    report = Pronunciation::Corpus::Judged.new(rescore: true).call

    expect(report).to(include("n" => 2, "accepted" => 1, "rejected" => 1, "rescored" => true))
    expect(report["bands"].values.sum { |band| band["n"] }).to(eq(2))
  end

  it "keeps nothing for a learner who is not collecting" do
    sign_in(create(:user))
    attempt

    expect(PronunciationRecording.count).to(be_zero)
  end
end
