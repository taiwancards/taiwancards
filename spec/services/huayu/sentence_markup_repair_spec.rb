# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SentenceMarkupRepair do
  let!(:source) do
    ContentSource.create!(
      slug: "wikivoyage",
      name: "Wikivoyage",
      license_commercial: true,
      register: :publicistic,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Wikivoyage."
    )
  end

  def sentence(text, meanings: {})
    lexeme = Lexeme.new(kind: :sentence, text:, meanings:, data: {"length" => text.scan(/\p{Han}/).length})
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  it "strips the template parameter name left in front of a sentence" do
    lexeme = sentence("content老闆和老闆娘都很親切，餐食料理好吃有特色。")

    expect(described_class.new.call.cleaned).to(eq(1))
    expect(lexeme.reload.text).to(eq("老闆和老闆娘都很親切，餐食料理好吃有特色。"))
    expect(lexeme.data["segments"]).not_to(include("content"))
  end

  it "keeps a sentence that only begins with an English word" do
    lexeme = sentence("contents是英文字。")

    expect(described_class.new.drift?).to(be(false))
    expect(lexeme.reload.text).to(eq("contents是英文字。"))
  end

  it "joins two sentences glued with a semicolon into one text" do
    lexeme = sentence("爺爺很喜歡喝烏龍茶。;台灣的烏龍茶很有名。")

    described_class.new.call

    expect(lexeme.reload.text).to(eq("爺爺很喜歡喝烏龍茶。台灣的烏龍茶很有名。"))
  end

  it "merges into the sentence that already has the clean text and keeps every translation" do
    clean = sentence(
      "依地質分類屬於雪山山脈帶的變質岩溫泉。",
      meanings: {"en" => "A metamorphic spring."}
    )
    damaged = sentence(
      "content依地質分類屬於雪山山脈帶的變質岩溫泉。",
      meanings: {"ja" => "変成岩の温泉。"}
    )
    word = create(:lexeme, kind: :word, text: "溫泉")
    sense = word.senses.create!(position: 0, gloss_zh: "溫度高的泉水。", content_source: source)
    example = sense
      .examples
      .create!(
        kind: :sentence,
        text: "依地質分類屬於雪山山脈帶的變質岩溫泉。",
        lexeme: damaged,
        content_source: source
      )

    result = described_class.new.call

    expect(result.merged).to(eq(1))
    expect(Lexeme.exists?(damaged.id)).to(be(false))
    expect(clean.reload.meanings).to(eq({"en" => "A metamorphic spring.", "ja" => "変成岩の温泉。"}))
    expect(example.reload.lexeme_id).to(eq(clean.id))
    expect(described_class.new.drift?).to(be(false))
  end
end
