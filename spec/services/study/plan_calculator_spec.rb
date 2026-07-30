# frozen_string_literal: true

require "rails_helper"

RSpec.describe Study::PlanCalculator do
  let(:user) { create(:user) }

  def tocfl(tag, position, texts)
    collection = Collection.create!(kind: :tocfl, name: "TOCFL #{tag}", level_tag: tag, position:)
    texts.each { |t| collection.add_lexeme(create(:lexeme, kind: :word, text: t)) }
    Collection.reset_counters(collection.id, :collection_items)
    collection
  end

  it "sums vocabulary up to the target level and derives a daily quota" do
    tocfl("Novice1", 0, %w[你 好 我])
    tocfl("A1", 2, %w[學校 電腦])
    tocfl("B1", 4, %w[經濟])

    plan = StudyPlan.create!(user:, target_level: "A1", target_date: Date.current + 4)
    calc = described_class.new(plan, now: Date.current)

    expect(calc.total).to(eq(5))
    expect(calc.known).to(eq(0))
    expect(calc.remaining).to(eq(5))
    expect(calc.days_left).to(eq(4))
    expect(calc.daily_new_quota).to(eq(2))
    expect(calc.est_minutes_per_day).to(eq(3))
  end

  it "counts known words as done and excludes higher levels" do
    n1 = tocfl("Novice1", 0, %w[你 好])
    tocfl("C", 6, %w[量子])
    known = n1.lexemes.first
    LexemeMemory.create!(lexeme: known, facet: :recognition, state: :review, user:, activated_at: Time.current)

    plan = StudyPlan.create!(user:, target_level: "Novice1", target_date: Date.current + 10)
    calc = described_class.new(plan)

    expect(calc.total).to(eq(2))
    expect(calc.known).to(eq(1))
    expect(calc.remaining).to(eq(1))
    expect(calc.remaining_by_kind["word"]).to(eq(1))
  end
end
