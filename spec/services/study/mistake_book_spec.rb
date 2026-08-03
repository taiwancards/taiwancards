# frozen_string_literal: true

require "rails_helper"

RSpec.describe Study::MistakeBook do
  let(:user) { create(:user) }

  def review(lexeme, rating:, at:)
    memory = LexemeMemory.find_or_create_by!(lexeme:, facet: :recognition, user:) do |m|
      m.state = :learning
      m.activated_at = at
    end

    LexemeReview.create!(
      lexeme:,
      lexeme_memory: memory,
      user:,
      facet: :recognition,
      rating: Fsrs::Scheduler::RATINGS.fetch(rating),
      reviewed_at: at
    )
  end

  it "collects recent lapses newest first without duplicates" do
    missed_twice = create(:lexeme)
    missed_once = create(:lexeme)
    passed = create(:lexeme)

    review(missed_once, rating: :again, at: 2.days.ago)
    review(missed_twice, rating: :again, at: 3.days.ago)
    review(missed_twice, rating: :again, at: 1.day.ago)
    review(passed, rating: :good, at: 1.hour.ago)

    book = described_class.new(user)

    expect(book.lexeme_ids).to(eq([missed_twice.id, missed_once.id]))
    expect(book.count).to(eq(2))
    expect(book.lexemes.map(&:id)).to(eq([missed_twice.id, missed_once.id]))
  end

  it "ignores lapses outside the window and other users" do
    stale = create(:lexeme)
    foreign = create(:lexeme)
    review(stale, rating: :again, at: 10.days.ago)

    other = create(:user)
    memory = LexemeMemory.create!(
      lexeme: foreign,
      facet: :recognition,
      user: other,
      state: :learning,
      activated_at: 1.day.ago
    )
    LexemeReview.create!(
      lexeme: foreign,
      lexeme_memory: memory,
      user: other,
      facet: :recognition,
      rating: Fsrs::Scheduler::RATINGS.fetch(:again),
      reviewed_at: 1.day.ago
    )

    expect(described_class.new(user).any?).to(be(false))
  end

  it "forecasts due cards for today, tomorrow and the week" do
    now = Time.current.change(hour: 9)
    today = create(:lexeme)
    tomorrow = create(:lexeme)
    later = create(:lexeme)

    LexemeMemory.create!(
      lexeme: today,
      facet: :recognition,
      user:,
      state: :review,
      activated_at: now,
      due_at: now + 1.hour
    )
    LexemeMemory.create!(
      lexeme: tomorrow,
      facet: :recognition,
      user:,
      state: :review,
      activated_at: now,
      due_at: now + 1.day
    )
    LexemeMemory.create!(
      lexeme: later,
      facet: :recognition,
      user:,
      state: :review,
      activated_at: now,
      due_at: now + 5.days
    )

    forecast = described_class.new(user, now:).forecast

    expect(forecast[:today]).to(eq(1))
    expect(forecast[:tomorrow]).to(eq(1))
    expect(forecast[:week]).to(eq(3))
  end
end
