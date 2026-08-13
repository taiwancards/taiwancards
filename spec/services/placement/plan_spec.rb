# frozen_string_literal: true

require "rails_helper"

RSpec.describe Placement::Plan do
  def intake(answers, short: false) = Placement::Intake.call(answers, short:)

  def rows(axis, grade, correct, count)
    Array.new(count) do
      {"axis" => axis, "grade" => grade, "difficulty" => Placement::Ability.difficulty_of(grade), "correct" => correct}
    end
  end

  let(:beginner) { {"experience" => "some", "script" => "pinyin", "characters" => "none", "variety" => "unsure"} }
  let(:reader) { {"experience" => "year", "script" => "zhuyin", "characters" => "read", "variety" => "taiwan"} }

  it "asks only about sound when the learner reads no characters" do
    step = described_class.new(intake(beginner), []).next_step

    expect(step.finished).to(be(false))
    expect(%w[listening tones]).to(include(step.axis))
  end

  it "opens every axis for a reader" do
    plan = described_class.new(intake(reader), [])

    expect(plan.next_step.finished).to(be(false))
    expect(intake(reader).axes).to(include("characters", "lexis", "sentences"))
  end

  it "adds a traditional-recognition axis for a China-variant background" do
    answers = reader.merge("variety" => "china")

    expect(intake(answers).axes).to(include("traditional"))
  end

  it "stops an axis that fails three times in a row" do
    asked = rows("listening", 1, false, 3)
    plan = described_class.new(intake(beginner), asked)

    expect(plan.next_step.axis).not_to(eq("listening"))
  end

  it "moves off an axis once it has had its share of the budget" do
    asked = rows("lexis", 3, true, described_class::CAP.fetch("lexis"))
    plan = described_class.new(intake(reader), asked)

    expect(plan.next_step.axis).not_to(eq("lexis"))
  end

  it "prefers an untouched heavy axis over an untouched light one" do
    step = described_class.new(intake(reader), []).next_step

    expect(described_class::WEIGHTS.fetch(step.axis)).to(eq(described_class::WEIGHTS.values.max))
  end

  it "sends an absolute beginner through a three-item sanity check" do
    result = intake({"experience" => "none", "script" => "none", "characters" => "none", "variety" => "none"})

    expect(result).to(be_sanity)
    expect(result.budget).to(eq(Placement::Intake::SANITY_BUDGET))
  end

  it "finishes once the budget is spent" do
    asked = rows("listening", 3, true, Placement::Intake::FULL_BUDGET)
    step = described_class.new(intake(reader), asked).next_step

    expect(step.finished).to(be(true))
    expect(step.outcome.grade).to(be_between(Placement::Ability::MIN_GRADE, Placement::Ability::MAX_GRADE))
  end

  it "climbs when answers are right and falls when they are wrong" do
    high = described_class.new(intake(reader), rows("lexis", 5, true, 4)).outcome
    low = described_class.new(intake(reader), rows("lexis", 5, false, 4)).outcome

    expect(high.grade).to(be > low.grade)
  end

  it "reports two grades when listening and reading diverge" do
    asked = rows("listening", 6, true, 4) + rows("characters", 1, false, 4)
    outcome = described_class.new(intake(reader), asked).outcome

    expect(outcome).to(be_split)
    expect(outcome.split["listening"]).to(be > outcome.split["reading"])
  end

  it "keeps the short test to six items" do
    expect(intake(reader, short: true).budget).to(eq(Placement::Intake::SHORT_BUDGET))
  end

  it "widens the tolerance only when the estimate is confident" do
    vague = described_class.new(intake(reader), rows("lexis", 4, true, 1)).outcome
    sure = described_class.new(intake(reader), rows("lexis", 4, true, 8)).outcome

    expect(Placement::Ability::TOLERANCES).to(include(vague.tolerance, sure.tolerance))
    expect(sure.error).to(be < vague.error)
  end
end
