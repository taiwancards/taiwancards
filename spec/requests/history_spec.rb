# frozen_string_literal: true

require "rails_helper"

RSpec.describe "History" do
  around { |example| travel_to(Time.zone.now.beginning_of_day + 12.hours) { example.run } }

  let!(:word) do
    create(
      :lexeme,
      text: "書店",
      readings: {"pinyin" => "shūdiàn", "zhuyin" => "ㄕㄨ ㄉㄧㄢˋ"},
      meanings: {"en" => "bookshop", "ru" => "книжный магазин"}
    )
  end

  def review!(user:, at:, rating: 3, facet: "recognition", stability: 40)
    memory = LexemeMemory.find_or_create_by!(user:, lexeme: word, facet:) do |record|
      record.activated_at = at
    end

    memory.update!(state: :review, stability:, due_at: at + stability.days, activated_at: memory.activated_at || at)
    LexemeReview.create!(user:, lexeme: word, facet:, rating:, reviewed_at: at, lexeme_memory: memory)
  end

  it "buckets a review by the Taiwan day, not the UTC day" do
    expect(Time.zone.name).to(eq("Asia/Taipei"))

    just_after_taipei_midnight = Time.zone.now.beginning_of_day + 30.minutes
    review!(user: @authenticated_user, at: just_after_taipei_midnight)

    get(progress_history_path)

    history = Stats::History.new
    expect(history.summary("today")[:total]).to(eq(1))
    expect(history.summary("yesterday")[:total]).to(eq(0))
  end

  it "never shows another user's memory strength for the same word" do
    stranger = create(:user)
    review!(user: stranger, at: Time.zone.now - 10.minutes, stability: 400)
    review!(user: @authenticated_user, at: Time.zone.now - 5.minutes, stability: 1)

    entries = Stats::History.new.entries("today")
    facet = entries.first[:facets].first

    expect(entries.size).to(eq(1))
    expect(facet[:memory].user_id).to(eq(@authenticated_user.id))
    expect(facet[:strength]).to(eq(:familiar))
  end

  it "counts only the signed-in user's reviews" do
    stranger = create(:user)
    review!(user: stranger, at: Time.zone.now - 1.minute)

    expect(Stats::History.new.summary("today")[:total]).to(eq(0))
  end

  it "renders the page with the reviewed word" do
    review!(user: @authenticated_user, at: Time.zone.now - 1.minute)

    get(progress_history_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("書店"))
  end
end
