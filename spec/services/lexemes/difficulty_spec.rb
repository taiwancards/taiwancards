# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::Difficulty do
  def character(text, rank) = create(:lexeme, :character, text:, data: {"freq_rank" => rank})

  def word(text, **data) = create(:lexeme, text:, data: data.stringify_keys)

  def attested(counts)
    frequency = instance_double(Huayu::WordFrequency)
    allow(frequency).to(receive(:adjusted)) { |text| counts.fetch(text, 0) }
    allow(Huayu::WordFrequency).to(receive(:instance).and_return(frequency))
  end

  def difficulty(lexeme) = lexeme.reload.data["difficulty"]

  before do
    attested({})
    character("我", 1)
    character("們", 2)
    character("鬱", 4000)
    character("鬯", 5000)
  end

  it "ranks a word of common characters below a word of rare ones, in difficulty and in score" do
    easy = word("我們")
    hard = word("鬱鬯")

    described_class.new.call

    expect(difficulty(easy)).to(be < difficulty(hard))
    expect(easy.score).to(be < hard.score)
  end

  it "spreads the dictionary scores across the whole scale" do
    described_class.new.call

    scores = Lexeme.where(kind: :character).order(:score).pluck(:text, :score)

    expect(scores.map(&:first)).to(eq(%w[我 們 鬱 鬯]))
    expect(scores.map(&:last).minmax).to(eq([described_class::SCORE_MIN, described_class::SCORE_MAX]))
  end

  it "changes nothing on a second run" do
    word("我們")
    first = described_class.new.call
    written = Lexeme.order(:id).pluck(:data, :score)

    expect(first).to(be_positive)
    expect(described_class.new.call).to(eq(0))
    expect(Lexeme.order(:id).pluck(:data, :score)).to(eq(written))
  end

  it "makes a word of a later teaching grade harder than the same characters taught early" do
    early = word("我們", tbcl_grade: 1)
    late = word("們我", tbcl_grade: 7)

    described_class.new.call

    expect(difficulty(early)).to(be < difficulty(late))
  end

  it "marks the words the corpus attests and pulls the frequent one down" do
    common = word("我們")
    rarer = word("們我")
    unseen = word("鬱鬯")
    attested("我們" => 900, "們我" => 3)

    described_class.new.call

    expect([common, rarer, unseen].map { |lexeme| lexeme.reload.data["corpus_attested"] }).to(eq([true, true, false]))
    expect(difficulty(common)).to(be < difficulty(rarer))
  end

  it "rewrites a word once the corpus starts attesting it" do
    lexeme = word("我們")
    described_class.new.call
    attested("我們" => 900)

    expect(described_class.new.call).to(eq(1))
    expect(lexeme.reload.data["corpus_attested"]).to(be(true))
  end

  it "treats a character missing from the frequency table as hard" do
    known = word("我們")
    unknown = word("我龘")

    described_class.new.call

    expect(difficulty(known)).to(be < difficulty(unknown))
  end

  it "leaves an entry with no Chinese characters untouched" do
    latin = word("LINE")

    described_class.new.call

    expect(latin.reload.data).not_to(include("difficulty"))
  end

  it "grades a practice phrase without judging it against the corpus" do
    phrase = create(:lexeme, kind: :phrase, text: "我們。", data: {"drill" => 1})
    attested("我們。" => 900)

    described_class.new.call

    expect(phrase.reload.data).to(include("difficulty"))
    expect(phrase.data).not_to(include("corpus_attested"))
  end

  it "orders the sentences by the difficulty they already carry" do
    harder = create(:lexeme, :sentence, text: "鬱鬯很難。", difficulty: 600)
    easier = create(:lexeme, :sentence, text: "我們很好。", difficulty: 100)

    described_class.new.call

    expect(easier.reload.score).to(be < harder.reload.score)
    expect(harder.data["difficulty"]).to(eq(600))
  end
end
