# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScanAlertJob do
  let!(:owner) { create(:user, :admin, locale: "ru") }

  before { ActionMailer::Base.deliveries.clear }

  it "tells the owner what happened, what learners see and where to act, and journals the letter" do
    described_class.perform_now("rejected", "2026-11-24T10:00:00+08:00")

    mail = ActionMailer::Base.deliveries.sole
    expect(mail.to).to(eq([User.owner_email]))
    expect(mail.subject).to(eq(I18n.t("scan.alerts.rejected.subject", locale: :ru)))
    text = mail.text_part.body.decoded
    expect(text).to(include(I18n.t("scan.alerts.rejected.learners", locale: :ru).first(40), "/ru/admin/scans"))
    expect(mail.html_part.body.decoded).to(include("/ru/admin/scans"))

    event = MailEvent.where(list: "alerts").sole
    expect(event).to(have_attributes(user: owner, list: "alerts", event: "sent", letter: mail.subject))
  end

  it "journals a failed delivery instead of raising" do
    allow(ScanAlertMailer).to(receive(:alert).and_raise(Net::SMTPFatalError.new("550 no")))

    expect { described_class.perform_now("credit", Time.current.iso8601) }.not_to(raise_error)
    expect(MailEvent.where(list: "alerts").sole).to(have_attributes(event: "failed", list: "alerts", letter: "credit"))
  end

  it "writes nothing when no owner address is configured" do
    allow(User).to(receive(:owner_email).and_return(nil))

    described_class.perform_now("ceiling", Time.current.iso8601)

    expect(ActionMailer::Base.deliveries).to(be_empty)
  end

  it "has a letter in every language for every kind" do
    Scans::Alerts::KINDS.product(I18n.available_locales).each do |kind, locale|
      mail = ScanAlertMailer.alert(kind:, at: Time.current, email: "o@example.com", locale: locale.to_s)

      expect(mail.subject).not_to(include("translation missing"))
      expect(mail.text_part.body.decoded).not_to(include("translation missing", "Translation missing"))
    end
  end
end
