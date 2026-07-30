# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::RestrictedFlagger do
  def lexeme(kind, text, sources)
    create(:lexeme, kind:, text:, sources:)
  end

  it "restricts Textbook sentences/collocations but never bare words or characters" do
    sentence = lexeme(:phrase, "我很好。", ["Textbook B1L02"])
    textbook_word = lexeme(:word, "霸凌", ["Textbook B3L05"])
    textbook_char = lexeme(:character, "不", ["Textbook B1L01"])
    open_phrase = lexeme(:phrase, "電腦", ["TBCL 5"])

    described_class.new.call

    expect(sentence.reload.restricted).to(be(true))
    expect(textbook_word.reload.restricted).to(be(false))
    expect(textbook_char.reload.restricted).to(be(false))
    expect(open_phrase.reload.restricted).to(be(false))
  end

  it "is idempotent and clears the flag when an open source is later added" do
    phrase = lexeme(:phrase, "打工度假", ["Textbook B2L01"])
    described_class.new.call
    expect(phrase.reload.restricted).to(be(true))

    phrase.update!(sources: phrase.sources + ["TOCFL B1"])
    described_class.new.call
    expect(phrase.reload.restricted).to(be(false))
  end
end
