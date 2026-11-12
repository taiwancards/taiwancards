# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dictation" do
  let(:row) do
    Huayu::ListeningClips::Row.new(
      text: "我也不知道",
      level: 1,
      clip: "voice-1.mp3",
      en: "I don't know either.",
      ru: "Я тоже не знаю.",
      vi: "Tôi cũng không biết.",
      emoji: nil,
      emoji_word: nil,
      emoji_category: nil
    )
  end

  let(:harder) { row.with(text: "經濟成長很快", level: 5, clip: "voice-5.mp3") }

  before do
    {
      "我" => %w[wǒ ㄨㄛˇ],
      "也" => %w[yě ㄧㄝˇ],
      "不" => %w[bù ㄅㄨˋ],
      "知道" => ["zhīdào", "ㄓ ㄉㄠˋ"]
    }.each do |text, (pinyin, zhuyin)|
      create(:lexeme, text:, readings: {"pinyin" => pinyin, "zhuyin" => zhuyin})
    end

    create(:lexeme, :sentence, text: row.text, segments: %w[我 也 不 知道])

    allow(Huayu::ListeningClips).to(receive(:all).and_return([row, harder]))
    allow(Huayu::ListeningClips).to(receive(:by_clip).and_return(nil))
    allow(Huayu::ListeningClips).to(receive(:by_clip).with(row.clip).and_return(row))
    allow(Huayu::ListeningClips).to(receive(:clip_url)) { |clip| "/listening/clips/#{clip}" }
  end

  def stream_headers = {"Accept" => "text/vnd.turbo-stream.html"}

  it "lets a guest take a round at the easiest level", :no_auth do
    get("/en/practice/dictation")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("voice-1.mp3"))
    expect(response.body).not_to(include("voice-5.mp3"))
    expect(response.body).to(include("data-controller=\"dictation\""))
  end

  it "serves the level the learner asks for" do
    read_in("ru")
    get("/ru/practice/dictation", params: {level: 5})

    expect(response.body).to(include("voice-5.mp3"))
    expect(response.body).to(include("aria-current=\"page\""))
  end

  it "grades an answer and shows each syllable against the recording" do
    post("/en/practice/dictation", params: {clip: row.clip, answer: "wo ye bu zhi dao"}, headers: stream_headers)

    expect(response).to(have_http_status(:ok))
    expect(response.media_type).to(eq("text/vnd.turbo-stream.html"))
    expect(response.body).to(include("data-percent=\"75\""))
    expect(response.body).to(include("I don&#39;t know either."))
  end

  it "grades a very long answer without choking on it" do
    post("/en/practice/dictation", params: {clip: row.clip, answer: "woyebuzhidao" * 100}, headers: stream_headers)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("data-percent="))
  end

  it "refuses a clip it does not know" do
    post("/en/practice/dictation", params: {clip: "elsewhere.mp3", answer: "我"}, headers: stream_headers)

    expect(response).to(have_http_status(:unprocessable_content))
  end

  it "counts a finished round on the practice page" do
    post(
      "/en/practice/dictation",
      params: {clip: row.clip, answer: "我也不知道", last: "1"},
      headers: stream_headers
    )

    expect(current_user.reload.practice_runs["dictation"]).to(eq(1))
  end
end
