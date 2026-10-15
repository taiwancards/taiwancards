# frozen_string_literal: true

require "rails_helper"

RSpec.describe ZhuyinHelper do
  def bases(html)
    Nokogiri::HTML.fragment(html).css("ruby .base").map(&:text)
  end

  def plain(html)
    fragment = Nokogiri::HTML.fragment(html)
    fragment.css("ruby").each(&:remove)
    fragment.text
  end

  it "pairs every character with its syllable" do
    expect(bases(helper.zhuyin_ruby("那邊", "ㄋㄚˋ ㄅㄧㄢ"))).to(eq(%w[那 邊]))
  end

  it "reads over brackets the reading leaves out" do
    html = helper.zhuyin_ruby("（台）斤", "ㄊㄞˊ ㄐㄧㄣ")

    expect(bases(html)).to(eq(%w[台 斤]))
    expect(plain(html)).to(eq("（）"))
  end

  it "keeps a mixed-script word paired when the reading covers it" do
    expect(bases(helper.zhuyin_ruby("K書", "ㄎㄟ ㄕㄨ"))).to(eq(%w[K 書]))
  end

  it "falls back to plain text when the counts disagree" do
    html = helper.zhuyin_ruby("故宮博物院", "ㄍㄨˋ ㄍㄨㄥ")

    expect(bases(html)).to(be_empty)
    expect(plain(html)).to(eq("故宮博物院"))
  end

  it "falls back to plain text without a reading" do
    expect(bases(helper.zhuyin_ruby("ABC", ""))).to(be_empty)
  end
end
