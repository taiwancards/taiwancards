# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Zhuyin audio" do
  let(:symbols) { %w[ㄅ ㄆ ㄇ ㄈ ㄉ ㄊ ㄋ ㄌ ㄍ ㄎ ㄏ ㄐ ㄑ ㄒ ㄓ ㄔ ㄕ ㄖ ㄗ ㄘ ㄙ] }
  let(:vowels) { %w[ㄚ ㄛ ㄜ ㄝ ㄞ ㄟ ㄠ ㄡ ㄢ ㄣ ㄤ ㄥ ㄦ] }
  let(:medials) { %w[ㄧ ㄨ ㄩ] }

  it "ships a clip for every one of the 37 zhuyin symbols" do
    all = symbols + vowels + medials
    expect(all.size).to(eq(37))

    missing = all.reject { |symbol| Rails.root.join("public/zhuyin/#{symbol}.opus").exist? }
    expect(missing).to(be_empty)
  end

  it "ships no empty clips" do
    empty = Rails.root.glob("public/zhuyin/*.opus").reject { |file| file.size.positive? }

    expect(empty).to(be_empty)
  end

  it "resolves a clip path for a known symbol and nothing for an unknown one" do
    helper = Class.new { include(ZhuyinHelper) }.new

    expect(helper.zhuyin_clip("ㄅ")).to(eq("/zhuyin/ㄅ.opus"))
    expect(helper.zhuyin_clip("ㄅㄚ")).to(be_nil)
    expect(helper.zhuyin_clip("")).to(be_nil)
    expect(helper.zhuyin_clip(nil)).to(be_nil)
  end

  it "serves a clip as audio, not as text" do
    get("/zhuyin/%E3%84%85.opus")

    expect(response).to(have_http_status(:ok))
    expect(response.media_type).to(eq("audio/ogg"))
  end
end
