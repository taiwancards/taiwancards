# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReminderMailer do
  let(:user) { create(:user) }

  %w[welcome first_cards due_cards still_due last_call scheduled].product(%w[en ru]).each do |trigger, locale|
    it "writes the #{trigger} letter in #{locale} with a way out" do
      count = %w[welcome first_cards].include?(trigger) ? 0 : 21
      delivery = ReminderDelivery.create!(user:, trigger:, count:, path: "/#{locale}/desk", locale:)
      mail = described_class.nudge(delivery)
      html = mail.html_part.body.to_s

      expect(mail.subject).to(be_present.and(satisfy { |subject| !subject.include?("translation missing") }))
      expect(html).not_to(include("translation missing"))
      expect(html).to(include("/l/", "/u/"))
      expect(mail.text_part.body.to_s).to(include("/u/", "/l/"))
      expect(html).to(include("21")) if count.positive?
      expect(MailLink.where(user:).pluck(:target)).to(include("/#{locale}/profile#reminders"))
    end
  end

  it "sends every site link through a one-time link of its own and keeps ids out of them" do
    delivery = ReminderDelivery.create!(user:, trigger: "due_cards", count: 21, path: "/en/study", locale: "en")
    mail = described_class.nudge(delivery)
    html = mail.html_part.body.to_s

    hrefs = html.scan(/href="([^"]+)"/).flatten
    expect(hrefs).to(all(match(%r{\Ahttp://[^/]+/[lu]/[A-Za-z0-9_-]{43}\z})))
    expect(MailLink.where(user:).pluck(:kind, :target)).to(
      contain_exactly(
        ["open", "/en/study"],
        ["open", "/en/profile#reminders"],
        ["open", "/en/profile#mail"],
        ["unsubscribe", ""]
      )
    )
    expect(hrefs.join).not_to(include(delivery.id.to_s + "/", "user"))
    expect(mail["List-Unsubscribe"].to_s).to(include("/u/"))
  end
end
