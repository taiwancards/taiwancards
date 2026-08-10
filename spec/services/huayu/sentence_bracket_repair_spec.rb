# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SentenceBracketRepair do
  let!(:source) do
    ContentSource.create!(
      slug: "wiki",
      name: "Wiki",
      license_commercial: true,
      register: :publicistic,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Wiki."
    )
  end

  def sentence(text)
    lexeme = Lexeme.new(kind: :sentence, text:, meanings: {}, data: {"length" => text.scan(/\p{Han}/).length})
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  it "cleans a sentence and keeps it" do
    lexeme = sentence("北港（）古稱笨港，位於雲林縣的一座城鎮。")

    result = described_class.new.call

    expect(result.cleaned).to(eq(1))
    expect(lexeme.reload.text).to(eq("北港古稱笨港，位於雲林縣的一座城鎮。"))
  end

  it "recomputes the stored length and segments" do
    lexeme = sentence("北港（）古稱笨港，位於雲林縣的一座城鎮。")

    described_class.new.call

    expect(lexeme.reload.data["length"]).to(eq(lexeme.text.scan(/\p{Han}/).length))
    expect(lexeme.data["segments"]).to(be_present)
  end

  it "removes a sentence that lost its subject" do
    lexeme = sentence("（）是高雄的一個分區，當地四面環山，境內丘陵起伏。")

    expect(described_class.new.call.removed).to(eq(1))
    expect(Lexeme.exists?(lexeme.id)).to(be(false))
  end

  it "removes a sentence whose cleaning leaves a dangling particle" do
    lexeme = sentence("在曼谷的演唱會開幕時也即興彈奏了匆促樂團的〈〉。")

    expect(described_class.new.call.removed).to(eq(1))
    expect(Lexeme.exists?(lexeme.id)).to(be(false))
  end

  it "removes a sentence whose cleaned form already exists" do
    twin = sentence("北港古稱笨港，位於雲林縣的一座城鎮。")
    damaged = sentence("北港（）古稱笨港，位於雲林縣的一座城鎮。")

    expect(described_class.new.call.removed).to(eq(1))
    expect(Lexeme.exists?(damaged.id)).to(be(false))
    expect(Lexeme.exists?(twin.id)).to(be(true))
  end

  it "keeps a sentence somebody is studying" do
    lexeme = sentence("（）是高雄的一個分區，當地四面環山，境內丘陵起伏。")
    user = create(:user)
    LexemeMemory.create!(lexeme: lexeme, user: user, facet: :recognition)

    result = described_class.new.call

    expect(result.removed).to(eq(0))
    expect(result.studied).to(eq(1))
    expect(Lexeme.exists?(lexeme.id)).to(be(true))
  end

  it "leaves a healthy corpus alone" do
    sentence("離八德區最近的機場為臺灣桃園國際機場（IATA：TPE）。")

    expect(described_class.new).not_to(be_drift)
  end

  it "drops a quote mark whose partner was left in the next sentence" do
    lexeme = sentence("俗話說：「欲速則不達。")

    result = described_class.new.call

    expect(result.cleaned).to(eq(1))
    expect(lexeme.reload.text).to(eq("俗話說：欲速則不達。"))
  end

  it "drops a bracket opened but never closed" do
    lexeme = sentence("(寶寶非新北市市民之家長也可參加，但無法領取禮袋。")

    described_class.new.call

    expect(lexeme.reload.text).to(eq("寶寶非新北市市民之家長也可參加，但無法領取禮袋。"))
  end

  it "leaves balanced quotation alone" do
    sentence("他說「今天天氣真好」，然後就出門了。")

    expect(described_class.new).not_to(be_drift)
  end

  it "reports without writing in a dry run" do
    lexeme = sentence("北港（）古稱笨港，位於雲林縣的一座城鎮。")

    expect(described_class.new.call(dry_run: true).cleaned).to(eq(1))
    expect(lexeme.reload.text).to(eq("北港（）古稱笨港，位於雲林縣的一座城鎮。"))
  end
end
