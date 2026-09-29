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
    allow(MailSettings).to(receive(:daily_limit).and_return(1))
    2.times { |i| delivery_for(create(:user, google_uid: "g-#{i}")) }

    described_class.perform_now(newsletter.id)

    expect(newsletter.deliveries.pending.count).to(eq(1))
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
