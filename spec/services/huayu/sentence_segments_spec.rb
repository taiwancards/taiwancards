# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SentenceSegments do
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

  def sentence(text, segments)
    lexeme = Lexeme.new(kind: :sentence, text:, data: {"segments" => segments})
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  it "splits a sentence into linked words and plain punctuation" do
    word = create(:lexeme, kind: :word, text: "學校")
    subject = sentence("我去學校。", %w[我 去 學校])

    runs = described_class.runs_for([subject])[subject]

    expect(runs.map(&:text)).to(eq(["我", "去", "學校", "。"]))
    expect(runs.last.lexeme).to(be_nil)
    expect(runs[2].lexeme).to(eq(word))
  end

  it "links single characters through the character entry when no word exists" do
    character = create(:lexeme, kind: :character, text: "我")
    subject = sentence("我來", %w[我 來])

    runs = described_class.runs_for([subject])[subject]

    expect(runs.first.lexeme).to(eq(character))
    expect(runs.last.lexeme).to(be_nil)
  end

  it "falls back to plain characters when segments drift from the text" do
    subject = sentence("你好嗎", %w[早安])

    runs = described_class.runs_for([subject])[subject]

    expect(runs.map(&:text)).to(eq(%w[你 好 嗎]))
    expect(runs.map(&:lexeme)).to(all(be_nil))
  end

  it "returns an empty map for no sentences" do
    expect(described_class.runs_for([])).to(eq({}))
  end
end
