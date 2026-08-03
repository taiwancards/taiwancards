# frozen_string_literal: true

require "rails_helper"

RSpec.describe MockExam::Listening do
  def row(text, level:, clip:, emoji: nil, category: nil)
    Huayu::ListeningClips::Row.new(
      text:,
      level:,
      clip:,
      en: "en #{text}",
      ru: nil,
      emoji:,
      emoji_word: emoji ? text[0, 2] : nil,
      emoji_category: category
    )
  end

  let(:pool) do
    [
      row("我去學校。", level: 1, clip: "a.mp3", emoji: "🏫", category: "place"),
      row("他在銀行。", level: 1, clip: "b.mp3", emoji: "🏦", category: "place"),
      row("我要喝咖啡。", level: 2, clip: "c.mp3", emoji: "☕", category: "drink"),
      row("今天天氣很好。", level: 2, clip: "d.mp3"),
      row("我明天要上班。", level: 2, clip: "e.mp3"),
      row("他晚上在家吃飯。", level: 2, clip: "f.mp3")
    ]
  end

  before { allow(Huayu::ListeningClips).to(receive(:pool).and_return(pool)) }

  it "builds deterministic papers mixing emoji and text questions" do
    first = described_class.build(band: "novice", seed: 9)
    second = described_class.build(band: "novice", seed: 9)

    expect(first.questions.map(&:clip)).to(eq(second.questions.map(&:clip)))
    expect(first.questions).not_to(be_empty)
    modes = first.questions.map(&:mode).uniq
    expect(modes - %w[emoji text]).to(be_empty)
  end

  it "keys every answer to the heard sentence" do
    paper = described_class.build(band: "novice", seed: 3)

    paper.questions.each do |question|
      correct = question.options[question.answer]
      if question.emoji?
        expect(correct).to(eq(pool.find { |r| r.text == question.text }.emoji))
      else
        expect(correct).to(eq(question.text))
      end
    end
  end
end
