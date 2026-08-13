# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::VariantForms do
  def word(text, meaning)
    create(:lexeme, kind: :word, text:, meanings: {"en" => meaning})
  end

  it "puts the standard spelling of a Taiwan word first" do
    plain = word("台獨", "Taiwan independence")
    word("臺獨", "Taiwan independence")

    expect(described_class.new.call(plain).map(&:text)).to(eq(%w[臺獨 台獨]))
  end

  it "keeps 臺 in front for a place in Taiwan" do
    plain = word("台北", "Taipei")
    word("臺北", "Taipei")

    expect(described_class.new.call(plain).map(&:text)).to(eq(%w[臺北 台北]))
  end

  it "puts 台 first where the character has nothing to do with Taiwan" do
    plain = word("舞台", "stage")
    rich = word("舞臺", "stage")
    rich.senses.create!(position: 0, meanings: {"en" => "a stage"})

    expect(described_class.new.call(plain).map(&:text)).to(eq(%w[舞台 舞臺]))
  end

  it "puts the counter spelling first for a word written three ways" do
    plain = word("櫃台", "counter")
    word("櫃臺", "counter")
    word("櫃檯", "counter")

    expect(described_class.new.call(plain).map(&:text)).to(eq(%w[櫃檯 櫃台 櫃臺]))
  end

  it "keeps a word whose only spelling we hold out of the list" do
    lonely = word("臺北", "Taipei")

    expect(described_class.new.call(lonely)).to(be_empty)
  end

  it "leaves single characters alone" do
    character = create(:lexeme, :character, text: "臺")
    create(:lexeme, :character, text: "台")

    expect(described_class.new.call(character)).to(be_empty)
  end

  it "ignores a word without any variant character" do
    lexeme = word("電視", "television")

    expect(described_class.new.call(lexeme)).to(be_empty)
  end
end
