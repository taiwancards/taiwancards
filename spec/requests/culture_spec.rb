# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Culture notes" do
  let(:lesson) { Huayu::CourseLessons.lessons.find(&:culture?) }

  it "lists every note under its course stage", :no_auth do
    get("/en/culture")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(lesson.culture_for(:en)["title"]))
    expect(response.body).to(include("id=\"#{lesson.slug}\""))
    expect(response.headers["Cache-Control"]).to(include("public"))
  end

  it "keeps a guest away from the login-only lesson link", :no_auth do
    get("/en/culture")

    expect(response.body).not_to(include("/en/course/#{lesson.slug}\""))
  end

  it "links a signed-in learner to the lesson the note comes from" do
    get("/ru/culture")

    expect(response.body).to(include(lesson.culture_for(:ru)["title"]))
    expect(response.body).to(include("/ru/course/#{lesson.slug}"))
  end
end
