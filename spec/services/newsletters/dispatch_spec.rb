# frozen_string_literal: true

require "rails_helper"

RSpec.describe Newsletters::Dispatch do
  include(ActiveJob::TestHelper)

  let(:recipient) { create(:user, google_uid: "g-1") }

  def stopped_newsletter(sent_at: 1.day.ago)
    Newsletter.create!(subject_en: "News", body_en: "<div>Hi</div>", sent_at:)
  end

  it "picks up the letters of a newsletter that stopped at the limit" do
    stopped = stopped_newsletter
    NewsletterDelivery.create!(newsletter: stopped, user: recipient, locale: "en")

    expect(described_class.resume).to(eq(1))
    assert_enqueued_with(job: NewsletterDispatchJob, args: [stopped.id, {retry_failed: false}])
  end

  it "takes one newsletter at a time, the oldest first" do
    older = stopped_newsletter(sent_at: 3.days.ago)
    newer = stopped_newsletter(sent_at: 1.day.ago)
    [newer, older].each { |item| NewsletterDelivery.create!(newsletter: item, user: recipient, locale: "en") }

    described_class.resume

    assert_enqueued_with(job: NewsletterDispatchJob, args: [older.id, {retry_failed: false}])
    assert_enqueued_jobs(1, only: NewsletterDispatchJob)
  end

  it "never sends a draft, whose test letter also waits in the list" do
    NewsletterDelivery.create!(newsletter: stopped_newsletter(sent_at: nil), user: recipient, locale: "en")

    expect(described_class.resume).to(eq(0))
  end

  it "leaves failed letters for the button" do
    NewsletterDelivery.create!(newsletter: stopped_newsletter, user: recipient, locale: "en", error: "rejected")

    expect(described_class.resume).to(eq(0))
  end

  it "finishes a long list over the following days, without shutting out reminders" do
    NewsletterDispatchJob.pause = 0
    allow(MailSettings).to(receive_messages(daily_limit: 5, reminder_reserve: 1))
    6.times { |i| create(:user, google_uid: "list-#{i}") }
    letter = stopped_newsletter(sent_at: nil)
    plan = Reminders::Planner::Plan.new(user: recipient, trigger: "due_cards", count: 5)

    perform_enqueued_jobs(only: NewsletterDispatchJob) { described_class.new(letter).call }
    expect(letter.deliveries.sent.count).to(eq(4))
    expect(letter.deliveries.pending.count).to(be_positive)
    expect(Reminders::Dispatch.new.call([plan]).size).to(eq(1))
    expect(described_class.resume).to(eq(0))

    travel(25.hours) do
      perform_enqueued_jobs(only: NewsletterDispatchJob) { described_class.resume }
    end

    expect(letter.deliveries.pending).to(be_empty)
  ensure
    NewsletterDispatchJob.pause = 0.6
  end

  it "waits while the limit is spent" do
    NewsletterDelivery.create!(newsletter: stopped_newsletter, user: recipient, locale: "en")
    allow(MailSettings).to(receive_messages(daily_limit: 20, reminder_reserve: 20))

    expect(described_class.resume).to(eq(0))
  end
end
