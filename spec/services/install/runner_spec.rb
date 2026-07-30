# frozen_string_literal: true

require "rails_helper"

RSpec.describe Install::Runner do
  subject(:checks) { described_class.new(io: StringIO.new).send(:integrity) }

  let(:licensed) do
    ContentSource.create!(slug: "open", name: "Open", license_commercial: true, attribution: "open")
  end

  let(:restricted) do
    ContentSource.create!(slug: "closed", name: "Closed", license_commercial: false, attribution: "closed")
  end

  def value(prefix) = checks.find { |name, _, _| name.start_with?(prefix) }[1]

  it "expects every check to come out at zero" do
    expect(checks.map(&:last)).to(all(eq(0)))
  end

  it "counts nothing on a healthy database" do
    sentence = create(:lexeme, kind: :sentence, text: "這是一個句子。", content_sources: [licensed])
    word = create(:lexeme, kind: :word, text: "句子")
    SentenceWord.create!(sentence: sentence, lexeme: word, gdex: 500)

    expect(checks.map { |_, actual, _| actual }).to(all(eq(0)))
  end

  it "sees a sentence no commercial license covers" do
    create(:lexeme, kind: :sentence, text: "這是一個句子。", content_sources: [restricted])

    expect(value("sentences no commercial")).to(eq(1))
  end

  it "ignores a sentence that also carries a licensed source" do
    create(:lexeme, kind: :sentence, text: "這是一個句子。", content_sources: [restricted, licensed])

    expect(value("sentences no commercial")).to(eq(0))
  end

  it "sees a word link whose sentence side is not a sentence" do
    word = create(:lexeme, kind: :word, text: "句子")
    other = create(:lexeme, kind: :word, text: "文章")
    SentenceWord.create!(sentence: other, lexeme: word, gdex: 500)

    expect(value("word links hanging")).to(eq(1))
  end

  it "sees a word link whose word side is a sentence" do
    sentence = create(:lexeme, kind: :sentence, text: "這是一個句子。", content_sources: [licensed])
    other = create(:lexeme, kind: :sentence, text: "另一個句子。", content_sources: [licensed])
    SentenceWord.create!(sentence: other, lexeme: sentence, gdex: 500)

    expect(value("word links hanging")).to(eq(1))
  end
end
