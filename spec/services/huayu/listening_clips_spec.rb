# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ListeningClips do
  let(:manifest) do
    {
      "clips" => [
        {
          "text" => "我去學校。",
          "level" => 1,
          "clip" => "a.mp3",
          "en" => "I go to school.",
          "ru" => "Я иду в школу.",
          "emoji" => "🏫",
          "emoji_word" => "學校",
          "emoji_category" => "place"
        },
        {"text" => "他喝咖啡。", "level" => 2, "clip" => "b.mp3", "en" => "He drinks coffee.", "ru" => nil},
        {
          "text" => "經濟成長很快。",
          "level" => 5,
          "clip" => "c.mp3",
          "en" => "The economy grows fast.",
          "ru" => nil
        }
      ]
    }
  end

  let(:path) { Pathname(Dir.mktmpdir).join("manifest.json") }

  before do
    path.write(JSON.generate(manifest))
    allow(AppData).to(receive(:media_path).and_call_original)
    allow(AppData).to(receive(:media_path).with("listening/manifest.json").and_return(path))
    described_class.reset!
  end

  after do
    described_class.reset!
    FileUtils.remove_entry(path.dirname)
  end

  it "indexes clips by sentence text" do
    row = described_class.for_text("我去學校。")

    expect(row.clip).to(eq("a.mp3"))
    expect(row.emoji?).to(be(true))
    expect(row.translation(:ru)).to(eq("Я иду в школу."))
    expect(described_class.for_text("他喝咖啡。").translation(:ru)).to(eq("He drinks coffee."))
  end

  it "filters pools by level" do
    expect(described_class.pool(max_level: 2).map(&:clip)).to(contain_exactly("a.mp3", "b.mp3"))
    expect(described_class.with_emoji(max_level: 2).map(&:clip)).to(eq(["a.mp3"]))
  end

  it "builds CDN urls when MEDIA_BASE_URL is set and local routes otherwise" do
    allow(ENV).to(receive(:[]).and_call_original)
    allow(ENV).to(receive(:[]).with("MEDIA_BASE_URL").and_return("https://audio.example.com"))
    expect(described_class.clip_url("a.mp3")).to(eq("https://audio.example.com/listening/audio/a.mp3"))

    allow(ENV).to(receive(:[]).with("MEDIA_BASE_URL").and_return(nil))
    expect(described_class.clip_url("a.mp3")).to(eq("/listening/clips/a"))
  end
end
