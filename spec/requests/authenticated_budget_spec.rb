# frozen_string_literal: true

require "rails_helper"

RSpec.describe "What a signed in reader costs" do
  PAGES = {
    "/desk" => 14,
    "/desks" => 8,
    "/progress" => 15,
    "/reader" => 6,
    "/triage" => 8,
    "/practice" => 4,
    "/practice/progress" => 8,
    "/profile" => 4,
    "/grammar" => 3,
    "/characters" => 8,
    "/dict" => 8,
    "/sentences" => 8,
    "/chengyu" => 8
  }.freeze

  before { sign_in(create(:user)) }

  PAGES.each do |path, budget|
    it "answers #{path} within #{budget} queries" do
      get(path)
      counted = count_queries { get(path) }.count

      expect(response).to(have_http_status(:ok).or(have_http_status(:redirect)))
      expect(counted).to(
        be <= budget,
        "#{path} ran #{counted} queries for one signed in reader — at 100 of them that is #{counted * 100} " \
          "round trips to a 0.5 CPU database"
      )
    end
  end
end
