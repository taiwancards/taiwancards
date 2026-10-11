# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Links in letters", :no_auth do
  let(:reader) { create(:user, locale: "ru") }
  let(:delivery) {
    ReminderDelivery.create!(
      user: reader,
      trigger: "due_cards",
      count: 20,
      path: "/ru/study?mode=daily&size=20",
      locale: "ru"
    )
  }

  def issue(kind: "open", target: "/ru/study?mode=daily&size=20", user: reader, at: Time.current)
    travel_to(at) { MailLink.issue(user:, kind:, list: "reminders", letter: "due_cards", target:, delivery:) }
  end

  def signed_in_as
    get(profile_path(locale: "ru"))
    return nil unless response.ok?

    User.find_by(email: response.body.scan(/[\w.+-]+@[\w.-]+/).find { |email| User.exists?(email:) })
  end

  def open!(link)
    get("/l/#{link.token}")
    post("/l/#{link.token}") if response.ok? && response.body.include?("auto-submit")
  end

  it "signs a signed-out reader in on the first click and opens exactly the promised page" do
    link = issue

    get("/l/#{link.token}")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("auto-submit", I18n.t("mail_links.opening.title", locale: :ru)))
    expect(link.reload.used_at).to(be_nil)

    post("/l/#{link.token}")
    expect(response).to(redirect_to("/ru/study?mode=daily&size=20"))
    expect(link.reload.used_at).to(be_present)
    expect(delivery.reload.clicked_at).to(be_present)
    expect(signed_in_as).to(eq(reader))
    expect(MailEvent.where(user: reader, event: "clicked").pluck(:source, :detail)).to(
      eq([["login", "/ru/study?mode=daily&size=20"]])
    )
  end

  it "lets a mail scanner fetch the link without signing anyone in or using it up" do
    link = issue

    3.times { get("/l/#{link.token}") }

    expect(link.reload).to(have_attributes(used_at: nil, clicks_count: 0))
    expect(signed_in_as).to(be_nil)
  end

  it "opens the page again for the same reader, and calls the link inactive for anyone signed out" do
    link = issue
    open!(link)

    get("/l/#{link.token}")
    expect(response).to(redirect_to("/ru/study?mode=daily&size=20"))

    delete(logout_path)
    get("/l/#{link.token}")
    expect(response).to(have_http_status(:gone))
    expect(response.body).to(include(I18n.t("mail_links.inactive.title", locale: :ru)))
    post("/l/#{link.token}")
    expect(response).to(have_http_status(:gone))
    expect(signed_in_as).to(be_nil)
    expect(MailEvent.where(user: reader, event: "clicked").pluck(:source)).to(eq(%w[login session inactive inactive]))
  end

  it "switches from someone else's account to the reader's on a fresh link, but never on a used one" do
    stranger = create(:user)
    fresh = issue
    used = issue
    used.consume!

    sign_in(stranger)
    get("/l/#{used.token}")
    expect(response).to(have_http_status(:gone))
    expect(signed_in_as).to(eq(stranger))

    open!(fresh)
    expect(response).to(redirect_to("/ru/study?mode=daily&size=20"))
    expect(signed_in_as).to(eq(reader))
  end

  it "treats every link in a letter on its own, so another link still works once" do
    button = issue
    schedule = issue(target: "/ru/profile#reminders")
    open!(button)
    delete(logout_path)

    open!(schedule)

    expect(response).to(redirect_to("/ru/profile#reminders"))
    expect(signed_in_as).to(eq(reader))
  end

  it "stops signing in a month after the letter" do
    link = issue(at: (MailLink::LOGIN_DAYS + 1).days.ago)

    open!(link)

    expect(response).to(have_http_status(:gone))
    expect(signed_in_as).to(be_nil)
  end

  it "refuses unknown, mangled and unsubscribe tokens and never leaves the site" do
    get("/l/nonsense")
    expect(response).to(have_http_status(:gone))

    get("/l/#{issue(kind: "unsubscribe", target: "").token}")
    expect(response).to(have_http_status(:gone))

    open!(issue(target: "//evil.test/steal"))
    expect(response).to(redirect_to("/ru/desk"))
  end

  it "keeps the link out of caches, referrers and search engines" do
    get("/l/#{issue.token}")

    expect(response.headers["Cache-Control"]).to(eq("no-store"))
    expect(response.headers["Referrer-Policy"]).to(eq("same-origin"))
    expect(response.headers["X-Robots-Tag"]).to(include("noindex"))
  end

  it "stores only a digest of the token" do
    link = issue

    expect(MailLink.where(token_digest: link.token)).to(be_empty)
    expect(MailLink.column_names).not_to(include("token"))
  end

  describe "unsubscribing from everything" do
    let(:reader) { create(:user, locale: "ru", google_uid: "g-7") }

    it "takes one click, needs no sign-in, and says so" do
      link = issue(kind: "unsubscribe", target: "")

      get("/u/#{link.token}")
      expect(response.body).to(include("auto-submit", reader.email))
      expect(reader.reload).to(have_attributes(reminders?: true, newsletter?: true))

      post("/u/#{link.token}")
      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include(I18n.t("mail_links.unsubscribe.done_title", locale: :ru)))
      expect(reader.reload).to(have_attributes(reminders?: false, newsletter?: false))
      expect(signed_in_as).to(be_nil)
      expect(MailEvent.where(user: reader, event: "unsubscribed").pluck(:list, :source)).to(
        contain_exactly(%w[reminders email_link], %w[newsletter email_link])
      )
    end

    it "answers the mail client's one-click request and keeps working afterwards" do
      link = issue(kind: "unsubscribe", target: "")

      post("/u/#{link.token}", params: {"List-Unsubscribe" => "One-Click"})
      post("/u/#{link.token}")

      expect(response).to(have_http_status(:ok))
      expect(MailEvent.where(user: reader, event: "unsubscribed").pluck(:source).uniq).to(eq(["one_click"]))
    end

    it "does not take an opening link for an unsubscribe" do
      post("/u/#{issue.token}")

      expect(response).to(have_http_status(:not_found))
      expect(reader.reload.reminders?).to(be(true))
    end
  end
end
