# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Graded reader" do
  it "lists the tiers that have texts" do
    get("/en/graded")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Graded TW Reader"))
    Graded::Library.tiers.each { |tier| expect(response.body).to(include("/graded/#{tier}")) }
  end

  it "opens the first text of a tier and shows its coverage" do
    tier = Graded::Library.tiers.first
    text = Graded::Library.texts(tier).first

    get("/en/graded/#{tier}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(text.lines.first.name(:en)))
    expect(response.body).to(include("inside the tier"))
  end

  it "opens a named text and lists its glosses" do
    tier = Graded::Library.tiers.first
    text = Graded::Library.texts(tier).last

    get("/ru/graded/#{tier}/#{text.id}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(text.notes.first.name(:ru)))
  end

  it "sends an unknown tier back to the index" do
    get("/en/graded/nope")

    expect(response).to(redirect_to("/en/graded"))
  end
end
