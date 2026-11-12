# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SentenceWordLinker do
  def sentence!(text, segments)
    create(:lexeme, :sentence, text:, segments:)
  end

  def linked(sentence)
    SentenceWord.where(sentence:).map { |row| row.lexeme.text }
  end

  def link!
    described_class.new(io: StringIO.new).call
  end

  it "links a sentence written with the other spelling to the entry that exists" do
    independence = Lexeme.create!(kind: :word, text: "臺灣獨立")
    Lexeme.create!(kind: :character, text: "台")
    sentence = sentence!("他們主張台灣獨立。", %w[他們 主張 台灣獨立])

    link!

    expect(SentenceWord.where(sentence:, lexeme: independence)).to(exist)
    expect(linked(sentence)).not_to(include("台"))
  end

  it "links one sentence to one entry when it writes the word both ways" do
    beer = Lexeme.create!(kind: :word, text: "台啤")
    sentence = sentence!("先喝台啤再喝臺啤。", %w[先 喝 台啤 再 喝 臺啤])

    link!

    expect(SentenceWord.where(sentence:, lexeme: beer).count).to(eq(1))
  end

  it "still reads a word with no entry in either spelling character by character" do
    north = Lexeme.create!(kind: :character, text: "北")
    sentence = sentence!("我們住在臺北縣。", %w[我們 住 在 臺北縣])

    link!

    expect(SentenceWord.where(sentence:, lexeme: north)).to(exist)
  end
end
