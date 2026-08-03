# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Grammar" do
  it "lists the lessons grouped by level" do
    get("/grammar")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Grammar"))
    expect(response.body).to(include("是"))
    expect(response.body).to(include("/grammar/shi"))
  end

  it "shows a lesson with formula, body and examples" do
    get("/grammar/1")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("linking verb"))
    expect(response.body).to(include("我是學生。"))
  end

  it "resolves lessons by slug and by head character" do
    get("/grammar/shi")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("linking verb"))

    get("/grammar/#{CGI.escape("是")}")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("linking verb"))
  end

  it "annotates examples with zhuyin and pinyin" do
    get("/grammar/shi")

    expect(response.body).to(include("ㄒㄩㄝ"))
    expect(response.body).to(include("xué"))
    expect(response.body).to(include("zy-run"))
  end

  it "surfaces grammar in the main search" do
    get("/search", params: {q: "是"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("/grammar/shi"))
  end

  it "shows the Russian explanation for Russian users" do
    sign_in(create(:user, locale: "ru"))

    get("/grammar/1")

    expect(response.body).to(include("глагол-связка"))
    expect(response.body).to(include("я студент"))
  end

  it "returns 404 for an unknown lesson" do
    get("/grammar/999")

    expect(response).to(have_http_status(:not_found))
  end
end
