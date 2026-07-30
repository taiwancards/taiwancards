# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::MoeAudio do
  around do |example|
    dir = Pathname(Dir.mktmpdir)
    original = ENV["DATA_ROOT"]
    ENV["DATA_ROOT"] = dir.to_s

    chars = dir.join("moe_audio")
    chars.join("audio").mkpath
    chars.join("audio", "0015.opus").write("x")
    chars.join("audio", "0017.opus").write("x")
    chars.join("audio", "2264A.opus").write("x")
    chars.join("index.json").write(
      {
        "version" => "20260626",
        "entries" => {
          "把" => [
            {"id" => "0015", "zhuyin" => "ㄅㄚˇ", "pinyin" => "bǎ", "head_ms" => 671},
            {"id" => "0017", "zhuyin" => "ㄅㄚˋ", "pinyin" => "bà", "head_ms" => 497}
          ]
        }
      }.to_json
    )

    words = dir.join("moe_audio_words")
    words.join("audio").mkpath
    words.join("index.json").write(
      {
        "version" => "20260626",
        "entries" => {
          "謝謝" => [
            {"id" => "123456789", "zhuyin" => "ㄒㄧㄝˋ　ㄒㄧㄝ˙", "pinyin" => "xièxie", "head_ms" => 900}
          ]
        }
      }.to_json
    )

    chars.join("notice.pdf").write("%PDF-1.4 stub")

    described_class.reset!
    example.run
    described_class.reset!
    ENV["DATA_ROOT"] = original
    FileUtils.remove_entry(dir)
  end

  it "finds a character and reports where the headword ends" do
    clip = described_class.for("把")

    expect(clip.scope).to(eq("chars"))
    expect(clip.head_ms).to(eq(671))
  end

  it "picks the reading that matches the zhuyin for a multi-reading character" do
    clip = described_class.for("把", zhuyin: "ㄅㄚˋ")

    expect(clip.id).to(eq("0017"))
    expect(clip.pinyin).to(eq("bà"))
  end

  it "ignores spacing when matching a reading" do
    clip = described_class.for("謝謝", zhuyin: "ㄒㄧㄝˋ ㄒㄧㄝ˙")

    expect(clip.scope).to(eq("words"))
  end

  it "prefers the word set over splitting into characters" do
    expect(described_class.for("謝謝").scope).to(eq("words"))
  end

  it "returns nothing for an entry with no recording" do
    expect(described_class.for("龘")).to(be_nil)
  end

  it "serves a clip that exists and refuses one that does not" do
    expect(described_class.clip_path("chars", "0015")).to(be_present)
    expect(described_class.clip_path("chars", "9999")).to(be_nil)
  end

  it "refuses a traversal attempt in the clip id" do
    expect(described_class.clip_path("chars", "../../secret")).to(be_nil)
    expect(described_class.clip_path("evil", "0015")).to(be_nil)
  end

  it "reports the data version for attribution" do
    expect(described_class.version).to(eq("20260626"))
  end

  it "keeps the usage notice the license requires us to retain" do
    expect(described_class).to(be_notice)
    expect(described_class.notice_path.basename.to_s).to(eq("notice.pdf"))
  end

  it "accepts the ids that carry a letter, as a few MOE entries do" do
    expect(described_class.clip_path("chars", "2264A")).to(be_present)
    expect(Rails.application.routes.url_helpers.moe_clip_path("words", "2264A")).to(be_present)
  end

  it "still refuses anything that is not a plain upper-case id" do
    expect(described_class.clip_path("chars", "../secret")).to(be_nil)
    expect(described_class.clip_path("chars", "0001.opus")).to(be_nil)
    expect(described_class.clip_path("chars", "abc1")).to(be_nil)
  end
end
