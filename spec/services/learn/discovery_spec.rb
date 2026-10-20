# frozen_string_literal: true

require "rails_helper"

RSpec.describe Learn::Discovery do
  let(:user) { create(:user, prefs: {"goal" => "tocfl", "level" => "2", "start_level" => "experienced"}) }
  let(:now) { Time.zone.local(2026, 10, 20, 12) }

  it "offers grammar from the level the learner is working on, not the one behind them" do
    grammar = described_class.new(user, now:).options.find { |option| option.kind == "grammar" }

    expect(grammar.level).to(eq(3))
  end

  it "skips a grammar lesson the learner has already opened" do
    first = Huayu::GrammarLessons.levels.fetch(3).first
    ActivityEvent.create!(
      user:,
      controller: "grammar",
      action: "show",
      verb: "GET",
      path: "/grammar/#{first.to_param}",
      created_at: now - 3.days
    )

    grammar = described_class.new(user, now:).options.find { |option| option.kind == "grammar" }

    expect(grammar.subject).not_to(eq(first))
  end

  it "points reading at the first unread text of the learner's tier" do
    first, second = Graded::Library.texts("chars300").first(2)
    GradedCompletion.record(user:, text_id: first.id)

    reading = described_class.new(user, now:).options.find { |option| option.kind == "graded" }

    expect(reading.subject).to(eq(second))
  end

  it "keeps grammar and reading away from a learner still on the first steps" do
    beginner = create(:user, prefs: {"goal" => "guided", "start_level" => "zero"})
    allow(Learn::Starter).to(receive(:new).and_return(instance_double(Learn::Starter, active?: true)))

    expect(described_class.new(beginner, now:).options.map(&:kind)).to(eq(%w[phrases culture pronunciation]))
  end

  it "rotates toward sections the learner has not touched this week" do
    PronunciationAttempt.where(user:).delete_all
    ActivityEvent.create!(
      user:,
      controller: "phrases",
      action: "index",
      verb: "GET",
      path: "/phrases",
      created_at: now - 1.day
    )
    ActivityEvent.create!(
      user:,
      controller: "grammar",
      action: "show",
      verb: "GET",
      path: "/grammar/x",
      created_at: now - 1.day
    )
    ActivityEvent.create!(
      user:,
      controller: "culture",
      action: "index",
      verb: "GET",
      path: "/culture",
      created_at: now - 1.day
    )

    kinds = 7.times.map { |day| described_class.new(user, now: now + day.hours).call(except: "graded")&.kind }.uniq

    expect(kinds).to(eq(["pronunciation"]))
  end
end
