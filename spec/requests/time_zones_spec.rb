# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The learner's time zone" do
  it "is asked from the browser on signed-in pages" do
    get(progress_path)

    expect(response.body).to(include("data-controller=\"time-zone\"", "data-time-zone-url-value=\"/time_zone\""))
  end

  it "is stored as the browser reports it" do
    put("/time_zone", params: {zone: "America/Los_Angeles"}, as: :json)

    expect(response).to(have_http_status(:no_content))
    expect(current_user.reload.time_zone).to(eq("America/Los_Angeles"))
  end

  it "ignores a zone nobody knows" do
    put("/time_zone", params: {zone: "Etc/Unknown"}, as: :json)

    expect(response).to(have_http_status(:no_content))
    expect(current_user.reload.time_zone).to(be_nil)
  end

  it "renders the day by that zone from then on" do
    current_user.update!(time_zone: "America/Los_Angeles")

    get(progress_path)

    expect(response.body).to(include("America/Los Angeles"))
  end

  it "stamps a new review with the learner's local day and leaves the old ones alone" do
    lexeme = create(:lexeme)
    memory = LexemeMemory.create!(lexeme:, user: current_user, facet: :recognition, activated_at: Time.current)
    attributes = {lexeme:, user: current_user, rating: 3, facet: 0, reviewed_at: Time.utc(2026, 9, 30, 2, 0)}
    before = memory.lexeme_reviews.create!(**attributes)
    current_user.update!(time_zone: "America/Los_Angeles")
    after = memory.lexeme_reviews.create!(**attributes)

    expect([before.reload.reviewed_on, after.reviewed_on]).to(eq([Date.new(2026, 9, 30), Date.new(2026, 9, 29)]))
  end
end
