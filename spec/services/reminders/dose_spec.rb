# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reminders::Dose do
  let(:user) { create(:user) }
  let(:now) { Time.zone.local(2026, 10, 20, 19) }
  let(:word) { create(:lexeme, kind: :word, text: "詞") }

  def study!(days:, cards:)
    memory = LexemeMemory.create!(user:, lexeme: word, facet: :recognition, state: :review, due_at: now)
    rows = days.times.flat_map { |day|
      cards.times.map { |index|
        lexeme = index.zero? ? word : create(:lexeme, kind: :word, text: "詞#{day}#{index}")
        {
          user_id: user.id,
          lexeme_id: lexeme.id,
          lexeme_memory_id: memory.id,
          facet: LexemeMemory.facets[:recognition],
          rating: 3,
          reviewed_at: now - (day + 1).days,
          reviewed_on: (now - (day + 1).days).to_date
        }
      }
    }
    LexemeReview.insert_all!(rows)
  end

  it "gives a newcomer the starter dose and never more than is due" do
    dose = described_class.new(user, now:)

    expect(dose.size).to(eq(20))
    expect(dose.call(2000)).to(eq(20))
    expect(dose.call(7)).to(eq(7))
  end

  it "keeps an occasional learner on the starter dose whatever they once crammed" do
    study!(days: 3, cards: 90)

    expect(described_class.new(user, now:).size).to(eq(20))
  end

  it "matches a regular learner's usual day, rounded to a friendly number" do
    study!(days: 10, cards: 37)

    expect(described_class.new(user, now:).size).to(eq(40))
  end

  it "keeps the same dose for every letter while the learner is away" do
    study!(days: 10, cards: 37)

    sizes = [2, 7, 21].map { |away| described_class.new(user, now: now + away.days).size }

    expect(sizes).to(eq([40, 40, 40]))
  end
end
