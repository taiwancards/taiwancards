# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mail log" do
  def entries(user) = MailEvent.where(email: user.email).order(:id).pluck(:list, :event, :source)

  it "records that a new account starts on both lists", :no_auth do
    user = create(:user)

    expect(entries(user)).to(eq([%w[reminders subscribed signup], %w[newsletter subscribed signup]]))
  end

  it "records every change made in the profile, and nothing when nothing changes" do
    user = current_user
    MailEvent.delete_all

    patch(profile_path, params: {user: {reminders: "0"}})
    patch(profile_path, params: {user: {reminders: "0"}})
    patch(profile_path, params: {user: {reminders: "1", newsletter: "0"}})

    expect(entries(user)).to(
      eq([%w[reminders unsubscribed profile], %w[reminders subscribed profile], %w[newsletter unsubscribed profile]])
    )
  end

  it "records newsletter unsubscribes from a letter", :no_auth do
    user = create(:user)
    newsletter = Newsletter.create!(
      subject_en: "News",
      subject_ru: "Новости",
      body_en: "Hi",
      body_ru: "Привет"
    )
    delivery = NewsletterDelivery.create!(newsletter:, user:, locale: "ru", sent_at: 1.hour.ago)
    MailEvent.delete_all

    post("/unsubscribe/#{delivery.signed_id(purpose: :unsubscribe)}")

    expect(entries(user)).to(eq([%w[newsletter unsubscribed email_link]]))
  end

  it "records each letter sent, each failure and each click", :no_auth do
    user = create(:user)
    MailEvent.delete_all
    sent = ReminderDelivery.create!(
      user:,
      trigger: "still_due",
      count: 20,
      path: "/en/study?mode=daily&size=20",
      locale: "en"
    )
    broken = ReminderDelivery.create!(user:, trigger: "last_call", count: 20, path: "/en/study", locale: "en")

    ReminderDeliveryJob.perform_now(sent.id)
    allow(ReminderMailer).to(receive(:nudge).and_raise(Net::SMTPFatalError.new("550 mailbox unavailable")))
    ReminderDeliveryJob.perform_now(broken.id)
    link = MailLink.issue(
      user:,
      kind: "open",
      list: "reminders",
      letter: "still_due",
      target: sent.path,
      delivery: sent
    )
    post("/l/#{link.token}")
    get("/l/#{link.token}")

    rows = MailEvent.where(user:).order(:id).pluck(:event, :letter, :detail)
    expect(rows.map(&:first)).to(eq(%w[sent failed clicked clicked]))
    expect(rows.map(&:second)).to(eq(%w[still_due last_call still_due still_due]))
    expect(rows.second.last).to(include("550 mailbox unavailable"))
  end

  it "saves the learner's own reminder schedule from the profile and logs each change" do
    MailEvent.delete_all

    patch(
      profile_path,
      params: {inline: "1", user: {reminder_schedule: {mode: "fixed", days: ["", "1", "5"], hour: "8"}}}
    )
    patch(
      profile_path,
      params: {inline: "1", user: {reminder_schedule: {mode: "fixed", days: ["", "1", "5"], hour: "8"}}}
    )
    patch(profile_path, params: {inline: "1", user: {reminder_schedule: {mode: "auto", days: [""], hour: "8"}}})

    expect(current_user.reload.reminder_mode).to(eq("auto"))
    expect(MailEvent.where(user: current_user).order(:id).pluck(:event, :detail)).to(
      eq([["scheduled", "1,5|8|#{current_user.time_zone || Time.zone_default.tzinfo.name}"], %w[scheduled auto]])
    )

    get(profile_path)
    expect(response.body).to(include("id=\"reminders\"", I18n.t("reminders.profile.fixed.title")))
  end

  it "notes the cards offered and the letter's plain text with every letter sent", :no_auth do
    user = create(:user, locale: "ru")
    delivery = ReminderDelivery.create!(user:, trigger: "scheduled", count: 15, path: "/ru/study", locale: "ru")

    ReminderDeliveryJob.perform_now(delivery.id)

    event = MailEvent.find_by!(user:, event: "sent")
    expect(event).to(have_attributes(letter: "scheduled", count: 15))
    expect(event.summary).to(
      start_with("Ваше время занятий: 15 карточек").and(include("около 2 мин."))
    )
    expect(event.summary).not_to(include("<", "http"))
  end

  it "keeps the history after the account is deleted", :no_auth do
    user = create(:user)
    email = user.email

    user.destroy!

    expect(MailEvent.where(email:).pluck(:user_id, :event)).to(eq([[nil, "subscribed"], [nil, "subscribed"]]))
  end

  describe "in the admin area" do
    let(:admin) { create(:user, :admin) }
    let(:learner) { create(:user, email: "learner@example.com") }

    before do
      sign_in(admin)
      MailEvent.log(learner, list: "reminders", event: "sent", letter: "welcome")
      MailEvent.log(learner, list: "reminders", event: "clicked", letter: "welcome", detail: "/ru/desk")
    end

    it "lists every event with the account and the letter, and filters them" do
      get(admin_mail_path)

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("learner@example.com", I18n.t("admin.mail.letters.welcome"), "/ru/desk"))

      get(admin_mail_path(event: "clicked", q: "learner"))
      expect(response.body).to(include("/ru/desk"))

      get(admin_mail_path(event: "failed"))
      expect(response.body).to(include(I18n.t("admin.mail.empty")))
    end

    it "shows the account's letters and current subscriptions on its page" do
      learner.update!(reminders: false)

      get(admin_user_path(learner))

      expect(response.body).to(include(I18n.t("admin.mail.account_title"), I18n.t("admin.mail.letters.welcome")))
      expect(response.body).to(
        include(I18n.t("admin.mail.off_since", date: I18n.l(learner.reminders_off_at, format: :short)))
      )
    end

    it "is closed to everyone else" do
      sign_in(learner)

      get(admin_mail_path)

      expect(response).to(redirect_to(root_path))
    end
  end
end
