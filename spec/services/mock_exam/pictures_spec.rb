# frozen_string_literal: true

require "rails_helper"

RSpec.describe MockExam::Pictures do
  def row(text, word, emoji, category, level: 1)
    Huayu::ListeningClips::Row.new(
      text:,
      level:,
      clip: "#{word}.mp3",
      en: "en #{text}",
      ru: "ru #{text}",
      emoji:,
      emoji_word: word,
      emoji_category: category
    )
  end

  let(:rows) do
    [
      row("我去學校。", "學校", "🏫", "place"),
      row("他在銀行。", "銀行", "🏦", "place"),
      row("我在車站等你。", "車站", "🚉", "place"),
      row("我要喝咖啡。", "咖啡", "☕", "drink"),
      row("她買了蘋果。", "蘋果", "🍎", "food")
    ]
  end

  before { allow(Huayu::ListeningClips).to(receive(:with_emoji).and_return(rows)) }

  it "asks for the picture matching the sentence with same-category distractors first" do
    paper = described_class.build(band: "novice", seed: 4)

    expect(paper.questions).not_to(be_empty)
    paper.questions.each do |question|
      source = rows.find { |r| r.text == question.text }
      expect(question.options[question.answer]).to(eq(source.emoji))
      expect(question.options.uniq.size).to(eq(3))
    end
  end

  it "offers only pictures from the same category, so the choice tests the sentence" do
    by_emoji = rows.to_h { |r| [r.emoji, r.emoji_category] }

    described_class.build(band: "novice", seed: 4).questions.each do |question|
      expect(question.options.map { |emoji| by_emoji.fetch(emoji) }.uniq.size).to(eq(1))
    end
  end

  it "skips a word whose category cannot supply two other pictures" do
    texts = described_class.build(band: "novice", seed: 4).questions.map(&:text)

    expect(texts).not_to(include("我要喝咖啡。"))
    expect(texts).not_to(include("她買了蘋果。"))
  end

  it "is deterministic per seed" do
    expect(described_class.build(band: "novice", seed: 7).questions.map(&:text))
      .to(eq(described_class.build(band: "novice", seed: 7).questions.map(&:text)))
  end
end
