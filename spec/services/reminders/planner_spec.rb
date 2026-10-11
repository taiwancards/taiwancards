# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reminders::Planner do
  let(:evening) { Time.zone.local(2026, 10, 20, 19, 5) }
  let(:user) { create(:user) }

  def visit!(user, day) = UserDay.insert_all([{user_id: user.id, day:}])

  def review!(user, at:, due_at: 1.day.ago)
    word = create(:lexeme, kind: :word, text: "詞#{SecureRandom.hex(3)}")
    memory = LexemeMemory.create!(user:, lexeme: word, facet: :recognition, state: :review, due_at:, activated_at: at)
    LexemeReview.create!(user:, lexeme: word, lexeme_memory: memory, facet: :recognition, rating: 3, reviewed_at: at)
  end

  def plans(at = evening) = travel_to(at) { described_class.new.call }

  it "nudges a learner who signed up yesterday and never reviewed a card" do
    visit!(user, evening.to_date - 1)

    expect(plans.map { |plan| [plan.user, plan.trigger] }).to(eq([[user, "first_cards"]]))
  end

  it "stays quiet outside the learner's hour and for anyone who turned reminders off" do
    visit!(user, evening.to_date - 1)

    expect(plans(evening.change(hour: 10))).to(be_empty)

    user.update!(reminders: false)
    expect(plans).to(be_empty)
  end

  it "never writes to an address nobody has confirmed" do
    user.update!(email_verified_at: nil)
    visit!(user, evening.to_date - 1)

    expect(plans).to(be_empty)
  end

  it "writes at the hour the learner usually studies" do
    visit!(user, evening.to_date - 2)
    3.times { |index| review!(user, at: evening.change(hour: 8) - (index + 2).days) }

    expect(plans(evening.change(hour: 8, min: 5)).map(&:trigger)).to(eq(["due_cards"]))
    expect(plans).to(be_empty)
  end

  it "walks the lapse milestones once each and stops on the next visit" do
    review!(user, at: evening - 30.days)
    visit!(user, evening.to_date - 2)

    expect(plans.map(&:count)).to(eq([1]))

    ReminderDelivery.create!(
      user:,
      trigger: "due_cards",
      count: 1,
      path: "/en/study",
      locale: "en",
      sent_at: evening,
      created_at: evening
    )
    expect(plans(evening + 1.day)).to(be_empty)
    expect(plans(evening + 5.days).map(&:trigger)).to(eq(["still_due"]))
  end

  it "sends one letter at the next milestone when an earlier one was missed, never the backlog" do
    review!(user, at: evening - 30.days)
    visit!(user, evening.to_date - 7)

    expect(plans.map(&:trigger)).to(eq(["still_due"]))
    expect(plans(evening + 1.day)).to(be_empty)
  end

  it "keeps only the learners' own schedules while automatic letters are stopped" do
    visit!(user, evening.to_date - 1)
    scheduled = create(:user)
    scheduled.update!(reminder_schedule: {mode: "fixed", days: %w[2], hour: "19"})
    visit!(scheduled, evening.to_date - 2)
    review!(scheduled, at: evening - 40.days)
    Setting.instance.pause_reminders!(true)

    expect(plans.map { |plan| [plan.user, plan.trigger] }).to(eq([[scheduled, "scheduled"]]))
    expect(Reminders::Dispatch.welcome(user)).to(be_empty)

    Setting.instance.pause_reminders!(false)
    expect(plans.map(&:trigger)).to(contain_exactly("scheduled", "first_cards"))
  end

  it "offers a starter dose instead of the whole backlog" do
    visit!(user, evening.to_date - 2)
    25.times { review!(user, at: evening - 40.days) }

    expect(plans.map { |plan| [plan.trigger, plan.count] }).to(eq([["due_cards", 20]]))
  end

  it "keeps welcome letters out of the nudge rhythm" do
    visit!(user, evening.to_date - 1)
    ReminderDelivery.create!(
      user:,
      trigger: "welcome",
      count: 0,
      path: "/",
      locale: "en",
      created_at: evening - 2.hours
    )

    expect(plans.map(&:trigger)).to(eq(["first_cards"]))
  end

  it "gives up after three ignored letters" do
    review!(user, at: evening - 40.days)
    visit!(user, evening.to_date - 7)
    3.times { |index|
      ReminderDelivery.create!(
        user:,
        trigger: "due_cards",
        count: 1,
        path: "/",
        locale: "en",
        created_at: evening - (index + 1).days
      )
    }

    expect(plans).to(be_empty)
  end

  describe "on the learner's own schedule" do
    let(:monday_morning) { Time.zone.local(2026, 10, 19, 7, 5) }

    before do
      user.update!(reminder_schedule: {mode: "fixed", days: %w[1 3], hour: "7"})
      visit!(user, monday_morning.to_date - 2)
      30.times { review!(user, at: monday_morning - 40.days) }
    end

    it "writes only on the chosen days at the chosen hour, with a sensible dose" do
      expect(plans(monday_morning).map { |plan| [plan.trigger, plan.count] }).to(eq([["scheduled", 20]]))
      expect(plans(monday_morning.change(hour: 8))).to(be_empty)
      expect(plans(monday_morning + 1.day)).to(be_empty)
      expect(plans(monday_morning + 2.days).map(&:trigger)).to(eq(["scheduled"]))
    end

    it "sends none of the automatic letters to someone who chose a schedule" do
      expect(plans(evening)).to(be_empty)
      expect(plans(evening - 1.day)).to(be_empty)
    end

    it "writes once a day, never after the day's study, and never once reminders are off" do
      ReminderDelivery.create!(
        user:,
        trigger: "scheduled",
        count: 20,
        path: "/en/study",
        locale: "en",
        created_at: monday_morning - 1.minute
      )
      expect(plans(monday_morning)).to(be_empty)

      ReminderDelivery.delete_all
      review!(user, at: monday_morning - 1.hour)
      expect(plans(monday_morning)).to(be_empty)

      LexemeReview.where(reviewed_at: monday_morning - 1.hour).delete_all
      user.update!(reminders: false)
      expect(plans(monday_morning)).to(be_empty)
    end

    it "writes nothing when no day is chosen" do
      user.update!(reminder_schedule: {mode: "fixed", days: [""], hour: "7"})

      expect((0..6).flat_map { |day| plans(monday_morning + day.days) }).to(be_empty)
    end
  end
end
