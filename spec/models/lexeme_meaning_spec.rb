# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexeme do
  it "gives a Japanese page no English line for an untranslated example sentence" do
    sentence = described_class.new(kind: :sentence, text: "我喝茶。", meanings: {"en" => "I drink tea."})
    word = described_class.new(kind: :word, text: "喝茶", meanings: {"en" => "to drink tea"})

    expect(sentence.meaning(:ja)).to(be_nil)
    expect(sentence.meaning(:en)).to(eq("I drink tea."))
    expect(sentence.meaning(:de)).to(eq("I drink tea."))
    expect(word.meaning(:ja)).to(eq("to drink tea"))
  end
end
