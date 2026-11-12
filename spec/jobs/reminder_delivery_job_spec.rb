# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReminderDeliveryJob do
  let(:delivery) do
    ReminderDelivery.create!(
      user: create(:user),
      trigger: "due_cards",
      count: 20,
      path: "/en/study?mode=daily&size=20",
      locale: "en"
    )
  end

  it "sends a reminder once however many times the job runs" do
    expect {
      2.times { described_class.perform_now(delivery.id) }
    }
      .to(change(ActionMailer::Base.deliveries, :size).by(1))

    expect(delivery.reload.sent_at).to(be_present)
    expect(MailEvent.where(user: delivery.user, event: "sent").count).to(eq(1))
  end

  it "does nothing for a delivery that no longer exists" do
    expect { described_class.perform_now(0) }.not_to(change(ActionMailer::Base.deliveries, :size))
  end
end
