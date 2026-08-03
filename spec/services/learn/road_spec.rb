# frozen_string_literal: true

require "rails_helper"

RSpec.describe Learn::Road do
  let(:user) { create(:user) }

  before { Current.user = user }
  after { Current.user = nil }

  def tocfl(tag, position, texts)
    collection = Collection.create!(kind: :tocfl, name: "TOCFL #{tag}", level_tag: tag, position:)
    texts.each { |t| collection.add_lexeme(create(:lexeme, kind: :word, text: t)) }
    Collection.reset_counters(collection.id, :collection_items)
    collection
  end

  def know(lexeme)
    LexemeMemory.create!(lexeme:, facet: :recognition, state: :review, user:, activated_at: Time.current)
  end

  it "orders milestones, marks the first unfinished one current and counts what is left" do
    n1 = tocfl("Novice1", 0, %w[你 好])
    tocfl("Novice2", 1, %w[謝謝])
    tocfl("C", 6, %w[量子])
    n1.lexemes.each { |lexeme| know(lexeme) }

    road = described_class.new(user)

    expect(road.milestones.map(&:level_tag)).to(eq(%w[Novice1 Novice2]))
    expect(road.milestones.first.state).to(eq(:done))
    expect(road.current.level_tag).to(eq("Novice2"))
    expect(road.current.remaining).to(eq(1))
  end

  it "keeps later levels as todo while an earlier one is current" do
    tocfl("Novice1", 0, %w[你])
    tocfl("A1", 2, %w[學校])

    road = described_class.new(user)

    expect(road.current.level_tag).to(eq("Novice1"))
    expect(road.milestones.last.state).to(eq(:todo))
  end

  it "reports days left when a plan exists" do
    tocfl("Novice1", 0, %w[你])
    StudyPlan.create!(user:, target_level: "Novice1", target_date: Date.current + 30)

    expect(described_class.new(user).days_left).to(eq(30))
  end

  it "has no plan data without a plan" do
    road = described_class.new(user)

    expect(road.plan).to(be_nil)
    expect(road.days_left).to(be_nil)
  end
end
