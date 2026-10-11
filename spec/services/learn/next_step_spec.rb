# frozen_string_literal: true

require "rails_helper"

RSpec.describe Learn::NextStep do
  def step_for(prefs) = described_class.new(create(:user, prefs:)).call

  def due!(user)
    word = create(:lexeme, kind: :word, text: "到期#{SecureRandom.hex(2)}")
    LexemeMemory.create!(
      user:,
      lexeme: word,
      facet: :recognition,
      state: :review,
      due_at: 1.hour.ago,
      activated_at: 2.days.ago
    )
  end

  it "starts a beginner on the first-steps track" do
    expect(step_for("goal" => "guided", "start_level" => "zero"))
      .to(have_attributes(kind: "starter", subject: Huayu::StarterTrack.lessons.first.slug))
  end

  it "falls back to the sounds when no track is loaded" do
    allow(Huayu::StarterTrack).to(receive(:available?).and_return(false))

    expect(step_for("goal" => "guided", "start_level" => "zero").kind).to(eq("zhuyin"))
  end

  it "sends anyone with due cards to review before anything new" do
    user = create(:user, prefs: {"goal" => "guided", "level" => "3", "start_level" => "experienced"})
    due!(user)

    expect(described_class.new(user).call.kind).to(eq("review"))
  end

  it "offers an exam candidate the level's grammar once today's quota is in" do
    user = create(:user, prefs: {"goal" => "tocfl", "level" => "3"})
    StudyPlan.create!(user:, target_level: "A1", target_date: 60.days.from_now.to_date)
    allow_any_instance_of(Study::DailyLoad).to(receive(:reached?).and_return(true))

    step = described_class.new(user).call

    expect(step).to(have_attributes(kind: "grammar", subject: 3))
  end

  it "recycles a class-goer's own deck when nothing is due or new" do
    user = create(:user, prefs: {"goal" => "classes"})
    deck = Collection.create!(kind: :manual, name: "Lesson 1", user:)
    word = create(:lexeme, kind: :word, text: "課本")
    deck.add_lexeme(word)
    LexemeMemory.create!(
      user:,
      lexeme: word,
      facet: :recognition,
      state: :review,
      due_at: 3.days.from_now,
      activated_at: 2.days.ago
    )

    expect(described_class.new(user).call).to(have_attributes(kind: "practice", subject: deck.id))
  end

  it "asks a class-goer without decks to add words" do
    expect(step_for("goal" => "classes").kind).to(eq("add_words"))
  end
end
