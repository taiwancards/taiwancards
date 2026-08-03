# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::VoicedSentences do
  let!(:source) do
    ContentSource.create!(
      slug: "spoken",
      name: "Spoken",
      license_commercial: true,
      register: :colloquial,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Spoken."
    )
  end

  def sentence(text, data: {})
    lexeme = Lexeme.new(kind: :sentence, text:, data:)
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  def clip(text)
    Huayu::ListeningClips::Row.new(
      text:,
      level: 1,
      clip: "#{text}.mp3",
      en: "en",
      ru: nil,
      emoji: nil,
      emoji_word: nil,
      emoji_category: nil
    )
  end

  it "marks the sentences the manifest can voice" do
    voiced = sentence("我去學校。")
    silent = sentence("我喝水。")
    allow(Huayu::ListeningClips).to(receive(:all).and_return([clip(voiced.text)]))

    result = described_class.new.call

    expect(result.marked).to(eq(1))
    expect(voiced.reload.data["audio"]).to(eq("common_voice"))
    expect(silent.reload.data).not_to(include("audio"))
  end

  it "does not touch a sentence that is already marked" do
    voiced = sentence("我去學校。", data: {"audio" => "common_voice"})
    allow(Huayu::ListeningClips).to(receive(:all).and_return([clip(voiced.text)]))

    expect(described_class.new.call.marked).to(eq(0))
  end

  it "clears the mark when the clip is gone from the manifest" do
    stale = sentence("我去學校。", data: {"audio" => "common_voice"})
    kept = sentence("我喝咖啡。", data: {"audio" => "common_voice"})
    allow(Huayu::ListeningClips).to(receive(:all).and_return([clip(kept.text)]))

    expect(described_class.new.call.cleared).to(eq(1))
    expect(stale.reload.data).not_to(include("audio"))
    expect(kept.reload.data["audio"]).to(eq("common_voice"))
  end

  it "does nothing when there is no manifest on the disk" do
    allow(Huayu::ListeningClips).to(receive(:all).and_return([]))

    expect(described_class.new.call.total).to(eq(0))
  end
end
