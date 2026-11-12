# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::WordRejectStore do
  let(:scratch) { Pathname(Dir.mktmpdir) }
  let(:path) { scratch.join("word_rejects.jsonl") }

  before { allow(described_class).to(receive(:path).and_return(path)) }
  after { scratch.rmtree }

  def entry(text, reason, note = nil) = described_class::Entry.new(text:, reason:, note:)

  it "removes word lexemes" do
    expect(described_class::KIND).to(eq(:word))
  end

  it "writes one compact line per word, sorted by text, with a trailing newline" do
    described_class.write([entry("鼠標", "off_taiwan", "Taiwan says 滑鼠"), entry("打吃", "renamed")])

    expect(path.read).to(
      eq(
        "{\"text\":\"打吃\",\"reason\":\"renamed\"}\n" \
          "{\"text\":\"鼠標\",\"reason\":\"off_taiwan\",\"note\":\"Taiwan says 滑鼠\"}\n"
      )
    )
  end

  it "reads back what it wrote" do
    described_class.write([entry("酸奶", "off_taiwan", "Taiwan says 優格")])

    expect(described_class.read).to(eq([entry("酸奶", "off_taiwan", "Taiwan says 優格")]))
    expect(described_class.texts).to(eq(Set["酸奶"]))
  end

  it "keeps one line per text when the same word is appended twice" do
    described_class.append([entry("定式", "renamed")])

    expect(described_class.append([entry("定式", "renamed", "now 定石")])).to(eq(0))
    expect(path.readlines.size).to(eq(1))
  end

  it "accepts the reasons a word is listed for" do
    expect(Huayu::RejectStore::REASONS).to(include("renamed", "off_taiwan"))
  end
end
