# frozen_string_literal: true

require "rails_helper"

RSpec.describe AudioHelper do
  let(:word) { create(:lexeme, kind: :word, text: "你好") }

  before do
    Huayu::WordClips.reset!
    allow(Huayu::MoeAudio).to(receive(:for).and_return(nil))
    allow(Huayu::WordClips::DATA).to(receive(:value).and_return({"clips" => {"你好" => {"clip" => "abc123.mp3"}}}))
  end

  after { Huayu::WordClips.reset! }

  it "falls back to a natural recording cut from Common Voice when the MOE has none" do
    expect(helper.audio_for(word)).to(include(url: "/word_clips/abc123", source: "common_voice"))
  end

  it "stays silent for a word nobody recorded" do
    expect(helper.audio_for(create(:lexeme, kind: :word, text: "公共汽車"))).to(be_nil)
  end
end
