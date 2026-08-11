# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sentences::Breakdown do
  let!(:source) do
    ContentSource.create!(
      slug: "spoken",
      name: "Spoken",
      license_commercial: true,
      register: :colloquial,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Spoken."
    )
  end

  def sentence!(text, segments)
    lexeme = Lexeme.new(kind: :sentence, text:, data: {"segments" => segments})
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  it "finds a unit that the dictionary keeps as a collocation" do
    create(:lexeme, kind: :collocation, text: "避雨", meanings: {"ru" => "укрываться от дождя"})
    lexeme = sentence!("有騎樓可避雨。", %w[有 騎樓 可 避雨])

    words = described_class.new(lexeme).call.words

    expect(words.find { |word| word.text == "避雨" }.lexeme).not_to(be_nil)
  end

  it "finds a unit that the dictionary keeps as a measure word" do
    create(:lexeme, kind: :measure_word, text: "顆", meanings: {"ru" => "штука (о круглом)"})
    lexeme = sentence!("一顆蛋。", %w[一 顆 蛋])

    words = described_class.new(lexeme).call.words

    expect(words.find { |word| word.text == "顆" }.lexeme).not_to(be_nil)
  end

  it "still reports a unit no kind of entry covers" do
    lexeme = sentence!("稍事休息。", %w[稍事 休息])

    result = described_class.new(lexeme).call

    expect(result.words.find { |word| word.text == "稍事" }.lexeme).to(be_nil)
    expect(result.unknown_count).to(eq(2))
  end

  it "prefers the word entry over the character of the same text" do
    create(:lexeme, :character, text: "有", meanings: {"ru" => "иероглиф"})
    create(:lexeme, kind: :word, text: "有", meanings: {"ru" => "иметь"})
    lexeme = sentence!("有。", %w[有])

    word = described_class.new(lexeme).call.words.first

    expect(word.lexeme.kind).to(eq("word"))
  end
end
