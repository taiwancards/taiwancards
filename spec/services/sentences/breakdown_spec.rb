# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sentences::Breakdown do
  let(:source) { ContentSource.create!(slug: "breakdown_spec", name: "Breakdown spec") }

  def sentence_for(text, segments)
    create(
      :lexeme,
      kind: :sentence,
      text: text,
      content_sources: [source],
      data: {"segments" => segments}
    )
  end

  it "glosses a 破音字 with the sense of the reading it actually has" do
    hui = create(
      :lexeme,
      :character,
      text: "會",
      readings: {"pinyin" => "huì", "zhuyin" => "ㄏㄨㄟˋ"},
      meanings: {},
      data: {"readings" => [{"pinyin" => "huì"}, {"pinyin" => "guì"}]}
    )
    hui.senses.create!(position: 0, reading: "guì", meanings: {"ru" => "чтение в названии уезда"})
    hui.senses.create!(position: 1, reading: "huì", meanings: {"ru" => "уметь, мочь"})

    words = described_class.new(sentence_for("會", ["會"])).call.words

    expect(words.first.senses.first.meaning(:ru)).to(eq("уметь, мочь"))
  end

  it "falls back to every sense when the character has only one reading" do
    shui = create(:lexeme, :character, text: "水", readings: {"pinyin" => "shuǐ"}, meanings: {})
    shui.senses.create!(position: 0, reading: nil, meanings: {"ru" => "вода"})

    words = described_class.new(sentence_for("水", ["水"])).call.words

    expect(words.first.senses.map { |sense| sense.meaning(:ru) }).to(eq(["вода"]))
  end
end
