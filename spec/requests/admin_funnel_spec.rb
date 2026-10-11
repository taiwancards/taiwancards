# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin funnel" do
  def review!(user, on:, count: 1)
    lexeme = create(:lexeme, kind: :word, text: "詞#{SecureRandom.hex(3)}")
    memory = LexemeMemory.create!(user:, lexeme:, facet: :recognition, state: :review, due_at: 1.day.from_now)
    count.times do
      LexemeReview.create!(
        user:,
        lexeme:,
        lexeme_memory: memory,
        facet: :recognition,
        rating: 3,
        reviewed_at: on.noon,
        reviewed_on: on
      )
    end
  end

  it "marks one presence day per visit day" do
    user = sign_in(create(:user))

    get("/dict")

    expect(UserDay.where(user:).pluck(:day)).to(eq([Date.current]))
  end

  it "keeps the page a new account signed up from", :no_auth do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "fresh-from-grammar",
      info: {email: "fresh@example.com", name: "Fresh"},
      credentials: {token: "t", refresh_token: "r", expires_at: 1.hour.from_now.to_i}
    )
    get("/login", headers: {"HTTP_REFERER" => "http://www.example.com/en/grammar?level=1"})
    get("/auth/google_oauth2/callback")

    expect(User.find_by(google_uid: "fresh-from-grammar").signup_from).to(eq("/grammar"))
  end

  it "counts a cohort from signup to its returns" do
    first = Date.current - 20
    keen = create(:user, prefs: {"start_level" => "zero"})
    idle = create(:user, :undecided)
    [first, first + 1, first + 8].each { |day| UserDay.insert_all([{user_id: keen.id, day:}]) }
    UserDay.insert_all([{user_id: idle.id, day: first}])
    review!(keen, on: first, count: 12)

    cohort = Admin::Funnel.new.cohorts.find { |row| row.week == first.beginning_of_week }

    expect(cohort.to_h.slice(:size, :started, :studied, :committed, :day_one, :week_two, :month_two))
      .to(eq(size: 2, started: 1, studied: 1, committed: 1, day_one: 1, week_two: 1, month_two: 0))
  end

  it "shows the funnel to an admin only" do
    get("/admin/funnel")
    expect(response).not_to(have_http_status(:ok))

    sign_in(create(:user, :admin))
    get("/admin/funnel")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Funnel", "Signup source"))
  end
end
