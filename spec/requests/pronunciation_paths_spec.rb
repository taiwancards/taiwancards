# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pronunciation template paths" do
  let(:data_path) { Rails.root.join("data/pronunciation") }

  before do
    skip("data/pronunciation not checked out") unless File.directory?(data_path.join("templates/taiwan"))

    ENV["PRONUNCIATION_DATA_PATH"] = data_path.to_s
    Pronunciation::TemplateStore.reset!
    Pronunciation::Acoustic::Syllables.load!
    allow(File).to(receive(:exist?).and_call_original)
    allow(File).to(receive(:read).and_call_original)
  end

  after do
    ENV.delete("PRONUNCIATION_DATA_PATH")
    Pronunciation::TemplateStore.reset!
  end

  def synthetic_wav(ms: 420, rate: 16_000)
    body = Array.new(ms * rate / 1000) { |i|
      t = i.to_f / rate
      envelope = [1.0, t / 0.03, ((ms / 1000.0) - t) / 0.05].min
      (Math.sin(2 * Math::PI * 125.0 * t) * envelope * 0.2 * 32_767).to_i
    }
    header = "RIFF" +
      [36 + (body.length * 2)].pack("V") +
      "WAVEfmt " +
      [16, 1, 1, rate, rate * 2, 2, 16].pack("VvvVVvv") +
      "data" +
      [body.length * 2].pack("V")
    (header + body.pack("s<*")).b
  end

  it "serves the citation template when the norm tries to leave the templates directory" do
    get("/pronunciation/templates/ma1", params: {norm: "../../huayu"})

    expect(response).to(have_http_status(:ok))
    expect(response.parsed_body).to(eq(Pronunciation::TemplateStore.instance.template("ma1")))
  end

  it "serves the citation template when the norm is not a string" do
    get("/pronunciation/templates/ma1", params: {norm: {x: "1"}})

    expect(response).to(have_http_status(:ok))
  end

  it "grades a recording whose expected syllables carry a path instead of a key" do
    expected = [
      {"char" => "媽", "pinyin" => "mā", "tone" => 1, "key" => "../../../huayu/starter_track"},
      {"char" => "麻", "pinyin" => "má", "tone" => 2, "key" => {"x" => "1"}},
      5
    ]
    audio = Rack::Test::UploadedFile.new(StringIO.new(synthetic_wav), "audio/wav", original_filename: "a.wav")

    post("/pronunciation/grade", params: {audio:, expected: expected.to_json, text: "媽麻", schedule: "false"})

    expect(response.status).to(be < 500)
    expect(File).not_to(have_received(:exist?).with(a_string_including("starter_track")))
    expect(File).not_to(have_received(:read).with(a_string_including("starter_track")))
  end
end
