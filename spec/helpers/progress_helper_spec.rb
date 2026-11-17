# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProgressHelper do
  let(:start) { Date.new(2026, 1, 1) }

  def streak(length, today:, rest_after: nil)
    days = (start...(start + length)).to_a
    days = days.map { |day| day > start + rest_after ? day + 1 : day } if rest_after
    Stats::DayStreak.new(days, today:).call
  end

  it "says the rest is used up on the last forgiven day" do
    expect(helper.streak_rest_note(streak(30, today: start + 32))).to(eq(I18n.t("stats.streak_rest_used")))
  end

  it "counts the rest days left while resting" do
    expect(helper.streak_rest_note(streak(30, today: start + 31))).to(eq(I18n.t("stats.streak_rest_left", count: 1)))
  end

  it "names the break already earned and the next tier" do
    expect(helper.streak_rest_note(streak(45, today: start + 44))).to(
      eq("A break of up to 2 days won't end this streak. Up to 4 days after 45 more days in a row.")
    )
  end

  it "names only the break at the top tier" do
    expect(helper.streak_rest_note(streak(95, today: start + 95))).to(
      eq("A break of up to 4 days won't end this streak.")
    )
  end

  it "points a newcomer at the first break" do
    expect(helper.streak_rest_note(streak(10, today: start + 9))).to(
      eq("After 20 more days in a row a break of up to 2 days will be forgiven.")
    )
  end

  it "says nothing about rest without a streak" do
    expect(helper.streak_rest_note(streak(10, today: start + 20))).to(be_nil)
    expect(helper.streak_status(streak(10, today: start + 20))).to(eq(I18n.t("stats.streak_none")))
  end

  it "marks a rest day on the activity map and leaves study days alone" do
    current = streak(40, today: start + 40, rest_after: 34)
    rest = I18n.l(start + 35, format: :short)

    expect(helper.activity_cell(start + 35, 0, 5, current)).to(
      eq(class: "bg-muted #{described_class::REST_MARK}", title: "#{rest}: rest day, the streak holds")
    )
    expect(helper.activity_cell(start + 34, 3, 5, current)[:class]).not_to(include(described_class::REST_MARK))
    expect(helper.streak_rests_note(current)).to(eq("One rest day in this streak, on #{rest}."))
  end
end
