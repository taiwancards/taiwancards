# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Notices", :no_auth do
  def sheets = response.body.scan("notice-sheet").size

  it "shows every notice to a guest" do
    get("/en/notices")

    expect(response).to(have_http_status(:ok))
    expect(sheets).to(eq(Huayu::TaiwanNotices.all.size))
  end

  it "makes the words of a notice clickable" do
    get("/en/notices")

    expect(response.body.scan("data-analyzer-target=\"word\"").size).to(be > 50)
  end

  it "prints the document furniture a Taiwanese notice carries" do
    get("/en/notices")

    expect(response.body).to(include("notice-kind"))
    expect(response.body).to(include("notice-seal"))
    expect(response.body).to(include("Subject:"))
  end

  it "narrows the board to one category" do
    get("/en/notices", params: {category: "health"})

    expect(response).to(have_http_status(:ok))
    expect(sheets).to(eq(Huayu::TaiwanNotices.in_category("health").size))
    expect(sheets).to(be < Huayu::TaiwanNotices.all.size)
  end

  it "ignores a category nobody publishes" do
    get("/en/notices", params: {category: "nonsense"})

    expect(response).to(have_http_status(:ok))
    expect(sheets).to(eq(Huayu::TaiwanNotices.all.size))
  end

  it "carries the translation of every line for the reader" do
    get("/ru/notices")

    expect(response.body).to(
      include("Дымовые окна в лестничных холлах давно в эксплуатации")
    )
  end
end
