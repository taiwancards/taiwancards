# frozen_string_literal: true

require "rails_helper"

RSpec.describe Placement::ItemBank do
  def word(text, meaning, grade: 2, freq: 10, **rest)
    create(
      :lexeme,
      kind: :word,
      text:,
      meanings: {"en" => meaning},
      data: {"tbcl_grade" => grade, "freq_rank" => freq},
      **rest
    )
  end

  def character(text, meaning, zhuyin, grade: 2, freq: 10)
    create(
      :lexeme,
      kind: :character,
      text:,
      meanings: {"en" => meaning},
      readings: {"zhuyin" => zhuyin, "pinyin" => "ma"},
      data: {"tbcl_grade" => grade, "freq_rank" => freq}
    )
  end

  def bank = described_class.new(rng: Random.new(42))

  def item(axis, grade: 2, exclude_ids: []) = bank.item_for(axis:, grade:, exclude_ids:)

  describe "shape shared by every axis" do
    before { 8.times { |i| word("詞#{i}", "meaning #{i}", freq: i + 1) } }

    it "builds a well-formed multiple-choice item" do
      row = item("lexis")

      expect(row["choices"].length).to(eq(described_class::CHOICES))
      expect(row["choices"].uniq.length).to(eq(described_class::CHOICES))
      expect(row["answer"]).to(be_between(0, described_class::CHOICES - 1))
      expect(row["axis"]).to(eq("lexis"))
      expect(row["difficulty"]).to(eq(Placement::Ability.difficulty_of(2)))
    end

    it "marks the correct choice as the answer" do
      row = item("lexis")

      expect(row["choices"][row["answer"]]).to(eq(Lexeme.find(row["lexeme_id"]).meaning))
    end

    it "never repeats an excluded lexeme" do
      seen = [item("lexis")["lexeme_id"]]

      expect(item("lexis", exclude_ids: seen)["lexeme_id"]).not_to(be_in(seen))
    end

    it "returns nothing when the grade has too few entries to build choices" do
      expect(item("lexis", grade: 6)).to(be_nil)
    end
  end

  it "excludes restricted lexemes" do
    8.times { |i| word("詞#{i}", "meaning #{i}", freq: i + 1) }
    word("受限", "restricted", freq: 1, restricted: true)

    ids = Array.new(6) { item("lexis")["lexeme_id"] }.compact

    expect(Lexeme.where(id: ids).pluck(:restricted)).to(all(be(false)))
  end

  it "asks the vocabulary-size axis a yes or no question and plants foils" do
    8.times { |i| word("詞彙#{i}", "meaning #{i}", freq: i + 1) }

    shared = bank
    rows = Array.new(20) { shared.item_for(axis: "vocab_size", grade: 2) }.compact

    expect(rows).to(all(include("format" => "yesno")))
    expect(rows.map { |row| row["answer"] }.uniq).to(contain_exactly(0, 1))
    expect(rows.select { |row| row["answer"] == 1 }).to(all(satisfy { |row| row["lexeme_id"].nil? }))
  end

  it "reads the grammar axis from a fixed bank so the construction, not the vocabulary, is tested" do
    row = item("grammar", grade: 3)

    expect(row["prompt"]).to(include("{}"))
    expect(row["choices"][row["answer"]]).to(be_present)
    expect(row["grade"]).to(eq(3))
  end

  it "tests Taiwanese usage against the mainland alternative" do
    rows = Array.new(12) { item("taiwan", grade: 2) }.compact
    answers = rows.map { |row| row["choices"][row["answer"]] }

    expect(answers).to(all(be_in(%w[不會 捷運])))
    expect(rows.flat_map { |row| row["choices"] }).to(include("不客氣").or(include("地鐵")))
  end

  it "asks a mainland learner to pick the traditional form of a simplified glyph" do
    row = item("traditional")

    expect(described_class::TRADITIONAL_PAIRS.values).to(include(row["prompt"]))
    expect(described_class::TRADITIONAL_PAIRS[row["choices"][row["answer"]]]).to(eq(row["prompt"]))
  end

  it "prompts with the reading and answers with the character on the script axis" do
    5.times { |i| character("字#{i}", "glyph #{i}", "ㄇㄚ#{"ˊ" * i}", freq: i + 1) }

    row = item("script")

    expect(row["prompt"]).to(start_with("ㄇㄚ"))
    expect(row["choices"]).to(include(Lexeme.find(row["lexeme_id"]).text))
  end

  it "returns nothing for an audio axis when no clip covers the syllable" do
    5.times { |i| character("音#{i}", "sound #{i}", "ㄅㄨㄥ#{"ˊ" * i}", freq: i + 1) }

    expect(item("tones")).to(be_nil)
  end
end
