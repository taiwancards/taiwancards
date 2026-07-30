# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TOCFL plan" do
  let!(:collection) do
    c = Collection.create!(kind: :tocfl, name: "TOCFL Novice 1", level_tag: "Novice1", position: 0)
    c.add_lexeme(create(:lexeme, kind: :word, text: "你好", data: {"moe_index" => 1}))
    c.add_lexeme(create(:lexeme, kind: :word, text: "謝謝", data: {"moe_index" => 2}))
    Collection.reset_counters(c.id, :collection_items)
    c
  end

  it "prompts to set a plan when none exists" do
    get("/plan")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Set a plan").or(include("No plan")))
  end

  it "creates a plan and shows the daily load and the today desk button" do
    post("/plan", params: {study_plan: {target_level: "Novice1", target_date: (Date.current + 5).to_s}})
    expect(response).to(redirect_to(study_plan_path))

    follow_redirect!
    expect(response.body).to(include("mode=today"))
    expect(StudyPlan.count).to(eq(1))
  end

  it "rejects a target date in the past" do
    post("/plan", params: {study_plan: {target_level: "A1", target_date: (Date.current - 1).to_s}})
    expect(response).to(have_http_status(:unprocessable_content))
    expect(StudyPlan.count).to(eq(0))
  end
end
