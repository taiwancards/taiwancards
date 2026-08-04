# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::MoeAudio do
  def with_base(value)
    previous = ENV["MEDIA_BASE_URL"]
    ENV["MEDIA_BASE_URL"] = value
    described_class.reset!
    yield
  ensure
    previous.nil? ? ENV.delete("MEDIA_BASE_URL") : ENV["MEDIA_BASE_URL"] = previous
    described_class.reset!
  end

  describe ".clip_url" do
    it "serves clips from the application when no media host is configured" do
      with_base(nil) do
        expect(described_class.clip_url("words", "000100011")).to(eq("/audio/moe/words/000100011"))
      end
    end

    it "points straight at the media host when one is configured" do
      with_base("https://audio.example.com") do
        expect(described_class.clip_url("words", "000100011")).to(
          eq("https://audio.example.com/moe_audio_words/audio/000100011.opus")
        )
      end
    end

    it "uses the character bucket path for the chars scope" do
      with_base("https://audio.example.com") do
        expect(described_class.clip_url("chars", "0001")).to(
          eq("https://audio.example.com/moe_audio/audio/0001.opus")
        )
      end
    end

    it "tolerates a trailing slash on the configured host" do
      with_base("https://audio.example.com/") do
        expect(described_class.clip_url("chars", "0001")).to(
          eq("https://audio.example.com/moe_audio/audio/0001.opus")
        )
      end
    end

    it "refuses an unknown scope" do
      with_base("https://audio.example.com") do
        expect(described_class.clip_url("secrets", "0001")).to(be_nil)
      end
    end

    it "refuses an id that could escape the bucket prefix" do
      with_base("https://audio.example.com") do
        expect(described_class.clip_url("chars", "../../etc/passwd")).to(be_nil)
        expect(described_class.clip_url("chars", "ab")).to(be_nil)
      end
    end

    it "notices the host changing after a reset" do
      with_base(nil) { expect(described_class.clip_url("chars", "0001")).to(start_with("/audio/moe")) }
      with_base("https://cdn.example.com") do
        expect(described_class.clip_url("chars", "0001")).to(start_with("https://cdn.example.com"))
      end
    end
  end

  describe "what reaches the runtime bucket" do
    let(:script) { Rails.root.join("bin/distribute").read }

    it "carries the manifests but not the clips, which the media bucket serves" do
      %w[moe_audio moe_audio_words].each do |scope|
        expect(script).to(include("media/#{scope}/index.json|media/#{scope}/index.json"))
        expect(script).not_to(include("media/#{scope}/audio"))
      end
    end

    it "carries the usage notice the MOE licence requires to stay reachable" do
      %w[moe_audio moe_audio_words].each do |scope|
        expect(script).to(include("media/#{scope}/notice.pdf|media/#{scope}/notice.pdf"))
        expect(script).to(include("media/#{scope}/ATTRIBUTION.txt|media/#{scope}/ATTRIBUTION.txt"))
      end
    end

    it "carries the restricted textbook audio, which the app hands out only behind its own gate" do
      expect(script).to(include("media/audio/textbook|media/audio/textbook"))
    end
  end
end
