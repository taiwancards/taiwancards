# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::KanjiBridge do
  let(:dir) { Pathname(Dir.mktmpdir("kanji-bridge")) }
  let(:characters) do
    {
      "counts" => {"characters" => 5},
      "patterns" => [{"id" => "單", "from" => "單", "to" => "単", "small" => false, "members" => %w[單 戰]}],
      "readings" => {"characters" => 3, "endings" => []},
      "characters" => {
        "學" => {"jp" => "学", "relation" => "differs", "level" => 1, "on" => "ガク"},
        "單" => {"jp" => "単", "relation" => "differs", "level" => 2, "on" => "タン", "pattern" => "單"},
        "戰" => {"jp" => "戦", "relation" => "differs", "level" => 3, "on" => "セン", "pattern" => "單"},
        "說" => {"jp" => "説", "relation" => "differs", "level" => 1, "on" => "セツ", "small" => true},
        "人" => {"jp" => "人", "relation" => "same", "level" => 1, "on" => "ジン"},
        "們" => {"relation" => "unused", "level" => 1},
        "嗯" => {"relation" => "unused"}
      }
    }
  end

  def install(words: nil)
    dir.join("bridge.json").write(JSON.generate(characters))
    stub_const("#{described_class}::CHARACTERS_PATH", dir.join("bridge.json"))
    stub_const("#{described_class}::WORDS_PATH", dir.join("words.json"))
    dir.join("words.json").write(words.is_a?(String) ? words : JSON.generate(words)) if words
    described_class.reset!
  end

  after { described_class.reset! }

  it "answers per character with its Japanese form, relation, on'yomi and pattern" do
    install

    expect(described_class.character("戰")).to(
      have_attributes(jp: "戦", on: "セン", pattern: "單", differs?: true)
    )
    expect(described_class.character("人")).to(be_same)
    expect(described_class.character("們")).to(be_unused)
    expect(described_class.character("龘")).to(be_nil)
    expect(described_class.pattern("單").to).to(eq("単"))
  end

  it "splits the differing characters into patterns, single differences and small print" do
    install

    expect(described_class.singletons.map(&:text)).to(eq(%w[學]))
    expect(described_class.small_print.map(&:text)).to(eq(%w[說]))
    expect(described_class.unused.map(&:text)).to(eq(%w[們]))
  end

  it "narrows every list to one level, dropping patterns with no member there" do
    install

    expect(described_class.patterns_at(level: 3).map(&:members)).to(eq([%w[戰]]))
    expect(described_class.patterns_at(level: 1)).to(be_empty)
    expect(described_class.entries(level: 1).map(&:text)).to(contain_exactly("學", "說", "人", "們"))
  end

  it "works without a word file" do
    install

    expect(described_class.words_available?).to(be(false))
    expect(described_class.word("勉強")).to(be_nil)
    expect(described_class.word_texts("shift")).to(eq([]))
  end

  it "reads the word tags and ignores entries it cannot use" do
    install(
      words: {
        "勉強" => {"kind" => "shift", "jp" => "無理に", "note" => "日本語の「勉強」は別の語"},
        "電話" => {"kind" => "same", "jp" => "電話"},
        "捷運" => {"kind" => "new"},
        "壞了" => {"kind" => "nonsense"},
        "東西" => "shift"
      }
    )

    expect(described_class.word("勉強")).to(have_attributes(kind: "shift", jp: "無理に", shift?: true))
    expect(described_class.word("捷運")).to(have_attributes(kind: "new", jp: nil, note: nil))
    expect(described_class.word("壞了")).to(be_nil)
    expect(described_class.word("東西")).to(be_nil)
    expect(described_class.word_texts("same")).to(eq(%w[電話]))
  end

  it "survives a damaged word file" do
    install(words: "{not json")

    expect(described_class.words_available?).to(be(false))
  end

  it "calls a measured share a rule only from ninety percent" do
    expect(described_class.reliable?(0.987)).to(be(true))
    expect(described_class.reliable?(0.6)).to(be(false))
  end
end
