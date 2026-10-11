# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reminders" do
  let(:delivery) do
    ReminderDelivery.create!(
      user: @authenticated_user,
      trigger: "due_cards",
      count: 23,
      path: "/en/study?mode=today",
      locale: "en",
      sent_at: 1.hour.ago
    )
  end

  around { |example| with_env("REMINDERS_TOKEN" => "secret-token") { example.run } }

  def with_env(values)
    previous = values.keys.to_h { |key| [key, ENV[key]] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  it "runs only for the bearer of the token" do
    post("/reminders/run")
    expect(response).to(have_http_status(:unauthorized))

    post("/reminders/run", headers: {"Authorization" => "Bearer wrong"})
    expect(response).to(have_http_status(:unauthorized))

    post("/reminders/run", headers: {"Authorization" => "Bearer secret-token"})
    expect(response).to(have_http_status(:ok))
    expect(response.parsed_body).to(include("queued"))
  end

  it "writes one number and one button" do
    mail = ReminderMailer.nudge(delivery)

    expect(mail.subject).to(eq("23 cards for today — about 4 min"))
    expect(mail.html_part.body.to_s).to(include("23", "Start reviewing", "/l/"))
    expect(mail["List-Unsubscribe"].to_s).to(include("/u/"))
  end

  it "offers to switch reminders back on at the end of a session" do
    @authenticated_user.update!(reminders: false)

    post("/reminders", headers: {"HTTP_REFERER" => "http://www.example.com/en/study"})

    expect(response).to(redirect_to("/en/study"))
    expect(@authenticated_user.reload.reminders?).to(be(true))
  end

  it "lets the admin stop every automatic letter, start them again, and logs both" do
    admin = create(:user, :admin)
    sign_in(admin)

    patch("/admin/reminders", params: {paused: "1"})
    expect(response).to(redirect_to("/en/admin/reminders"))
    expect(Setting.instance.reminders_paused?).to(be(true))
    expect(Reminders::Dispatch.welcome(create(:user))).to(be_empty)

    get("/admin/reminders")
    expect(response.body).to(include(I18n.t("admin.reminders.resume")))

    patch("/admin/reminders", params: {paused: "0"})
    expect(Setting.instance.reminders_paused?).to(be(false))
    expect(MailEvent.where(user: admin).order(:id).pluck(:list, :event, :source)).to(
      eq(
        [
          %w[reminders subscribed signup],
          %w[newsletter subscribed signup],
          %w[reminders paused admin],
          %w[reminders resumed admin]
        ]
      )
    )
  end

  it "shows the admin what went out and how people reacted" do
    delivery.update!(clicked_at: Time.current)
    sign_in(create(:user, :admin))

    get("/admin/reminders")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("due_cards", "config/reminders.yml"))
  end
end
