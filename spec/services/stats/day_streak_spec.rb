# frozen_string_literal: true

require "rails_helper"

RSpec.describe Stats::DayStreak do
  let(:start) { Date.new(2026, 1, 1) }

  def streak(days, today:)
    described_class.new(days, today:).call
  end

  def run(from, length)
    (from...(from + length)).to_a
  end

  describe "a real learner who took one day off after 91 days" do
    let(:studied) {
      [
        Date.new(2026, 8, 11),
        Date.new(2026, 8, 12),
        *(Date.new(2026, 8, 15)..Date.new(2026, 11, 13)),
        Date.new(2026, 11, 15),
        Date.new(2026, 11, 16)
      ]
    }
    let(:through_13th) { studied.select { |day| day <= Date.new(2026, 11, 13) } }

    it "keeps the streak across the rest day without counting it" do
      expect(streak(studied, today: Date.new(2026, 11, 16))).to(
        have_attributes(
          current: 93,
          since: Date.new(2026, 8, 15),
          longest: 93,
          days: 95,
          state: :done,
          rests: [Date.new(2026, 11, 14)],
          allowance: 0,
          ahead: described_class::Ahead.new(days: 28, rest: 2)
        )
      )
    end

    it "offers four days off once 90 clean days are in" do
      expect(streak(through_13th, today: Date.new(2026, 11, 14))).to(
        have_attributes(current: 91, since: Date.new(2026, 8, 15), state: :pending, rests: [], allowance: 4, ahead: nil)
      )
    end

    it "is resting on the first day off and spends one of the four" do
      expect(streak(through_13th, today: Date.new(2026, 11, 15))).to(
        have_attributes(current: 91, state: :resting, rests: [Date.new(2026, 11, 14)], allowance: 3, ahead: nil)
      )
    end

    it "is still resting after four days off with nothing left to spend" do
      expect(streak(through_13th, today: Date.new(2026, 11, 18))).to(
        have_attributes(
          current: 91,
          state: :resting,
          rests: (Date.new(2026, 11, 14)..Date.new(2026, 11, 17)).to_a,
          allowance: 0
        )
      )
    end

    it "ends on the fifth day off" do
      expect(streak(through_13th, today: Date.new(2026, 11, 19))).to(
        have_attributes(
          current: 0,
          since: nil,
          longest: 91,
          days: 93,
          state: :none,
          rests: [],
          allowance: 0,
          ahead: nil
        )
      )
    end
  end

  it "breaks on a missed day before 30 clean days" do
    days = run(start, 29) + run(start + 30, 3)

    expect(streak(days, today: days.last)).to(have_attributes(current: 3, since: start + 30, longest: 29))
  end

  it "forgives two days after 30 clean days but not a second break five days later" do
    first = run(start, 30)
    second = run(start + 32, 5)
    third = run(start + 38, 2)
    days = first + second + third

    expect(streak(first + second, today: second.last)).to(
      have_attributes(current: 35, since: start, rests: [start + 30, start + 31], allowance: 0)
    )
    expect(streak(days, today: days.last)).to(have_attributes(current: 2, since: start + 38, longest: 35, rests: []))
  end

  it "does not forgive three days after 30 clean days" do
    days = run(start, 30) + run(start + 33, 1)

    expect(streak(days, today: days.last)).to(have_attributes(current: 1, longest: 30))
  end

  it "forgives four days after 90 clean days but not five" do
    clean = run(start, 90)

    expect(streak(clean + [start + 94], today: start + 94)).to(have_attributes(current: 91, rests: run(start + 90, 4)))
    expect(streak(clean + [start + 95], today: start + 95)).to(have_attributes(current: 1, longest: 90))
  end

  it "restarts the count toward 90 after a rest" do
    days = run(start, 60) + run(start + 61, 60)

    expect(streak(days, today: days.last)).to(
      have_attributes(current: 120, allowance: 2, ahead: described_class::Ahead.new(days: 30, rest: 4))
    )
  end

  it "points a newcomer at the first tier" do
    days = run(start, 10)

    expect(streak(days, today: days.last + 1)).to(
      have_attributes(current: 10, state: :pending, allowance: 0, ahead: described_class::Ahead.new(days: 20, rest: 2))
    )
  end

  it "is empty without study days" do
    expect(streak([], today: start)).to(
      have_attributes(current: 0, since: nil, longest: 0, days: 0, state: :none, rests: [], allowance: 0, ahead: nil)
    )
  end

  it "ends a short run once a whole day was missed" do
    expect(streak([start], today: start + 2)).to(have_attributes(current: 0, since: nil, longest: 1, state: :none))
  end
end
