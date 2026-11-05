# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsletterDispatchJob do
  let(:newsletter) {
    Newsletter.create!(
      subject_en: "News",
      subject_ru: "Новости",
      body_en: "<div>Hi</div>",
      body_ru: "<div>Привет</div>"
    )
  }

  before do
    described_class.pause = 0
    ActionMailer::Base.deliveries.clear
  end

  after { described_class.pause = 0.6 }

  def delivery_for(user) = NewsletterDelivery.create!(newsletter:, user:, locale: user.locale)

  it "sends each pending letter once" do
    first = delivery_for(create(:user, google_uid: "g-1"))
    second = delivery_for(create(:user, google_uid: "g-2"))

    2.times { described_class.perform_now(newsletter.id) }

    expect(ActionMailer::Base.deliveries.size).to(eq(2))
    expect([first.reload, second.reload].map(&:sent_at)).to(all(be_present))
  end

  it "stops at the daily limit and leaves the rest for later" do
    allow(MailSettings).to(receive_messages(daily_limit: 1, reminder_reserve: 0))
    2.times { |i| delivery_for(create(:user, google_uid: "g-#{i}")) }

    described_class.perform_now(newsletter.id)

    expect(newsletter.deliveries.pending.count).to(eq(1))
  end

  it "leaves room for reminders and counts the ones already sent" do
    allow(MailSettings).to(receive_messages(daily_limit: 4, reminder_reserve: 1))
    5.times { |i| delivery_for(create(:user, google_uid: "g-#{i}")) }

    described_class.perform_now(newsletter.id)
    expect(ActionMailer::Base.deliveries.size).to(eq(3))

    allow(MailSettings).to(receive_messages(daily_limit: 6, reminder_reserve: 1))
    2.times { ReminderDelivery.create!(user: create(:user), trigger: "due_cards", count: 1, path: "/", locale: "en") }
    described_class.perform_now(newsletter.id)
    expect(ActionMailer::Base.deliveries.size).to(eq(4))
  end

  it "tries a failed letter again only when asked by hand" do
    failed = delivery_for(create(:user, google_uid: "g-1"))
    failed.update!(error: "Net::SMTPFatalError: rejected")

    described_class.perform_now(newsletter.id, retry_failed: false)
    expect(ActionMailer::Base.deliveries).to(be_empty)

    described_class.perform_now(newsletter.id)
    expect(ActionMailer::Base.deliveries.size).to(eq(1))
    expect(failed.reload.error).to(be_nil)
  end

  it "skips someone who unsubscribed after the send began and stops counting them as waiting" do
    delivery_for(create(:user, google_uid: "g-1", newsletter_unsubscribed_at: Time.current))

    described_class.perform_now(newsletter.id)

    expect(ActionMailer::Base.deliveries).to(be_empty)
    expect(newsletter.deliveries.pending).to(be_empty)
  end

  it "records a failure and keeps the letter pending" do
    delivery = delivery_for(create(:user, google_uid: "g-1"))
    allow(NewsletterMailer).to(receive(:issue).and_raise(Net::SMTPServerBusy, "try later"))

    described_class.perform_now(newsletter.id)

    expect(delivery.reload.sent_at).to(be_nil)
    expect(delivery.error).to(include("try later"))
  end
end
