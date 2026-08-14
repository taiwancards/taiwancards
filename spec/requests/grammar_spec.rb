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
    expect(response.body).to(include("the verb &quot;to be&quot;"))
    expect(response.body).to(include("A + "))
  end

  it "links example words that exist in the dictionary" do
    create(:lexeme, kind: :word, text: "學生", meanings: {"en" => "student"})

    get("/grammar/1")

    expect(response.body).to(include("/dict/#{CGI.escape("學生")}"))
  end

  it "filters the index by level" do
    get("/grammar", params: {level: 1})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("/grammar/shi"))
    expect(response.body).not_to(include("/grammar/le-completed"))
  end

  it "resolves lessons by slug and by head character" do
    get("/grammar/shi")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("the verb &quot;to be&quot;"))

    get("/grammar/#{CGI.escape("是")}")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("the verb &quot;to be&quot;"))
  end

  it "annotates the explanation and its examples with zhuyin and pinyin" do
    get("/grammar/shi")

    expect(response.body).to(include("ㄒㄩㄝ"))
    expect(response.body).to(include("zy-reading"))
    expect(response.body).to(include("zh-term"))
  end

  it "surfaces grammar in the main search" do
    get("/search", params: {q: "是"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("/grammar/shi"))
  end

  it "shows the Russian explanation on the Russian url" do
    sign_in(create(:user, locale: "ru"))

    get("/ru/grammar/1")

    expect(response.body).to(include("связка «быть»"))
    expect(response.body).to(include("я студент"))
  end

  it "keeps an excluded point reachable but out of the listing" do
    get("/grammar")
    expect(response.body).not_to(include("/grammar/yihuir-alternating"))

    get("/grammar/yihuir-alternating")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Not part of the course"))
  end

  it "marks a point the TBCL list does not carry" do
    get("/grammar/hen-linker")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Outside the TBCL list"))

    get("/grammar/shi")
    expect(response.body).not_to(include("Outside the TBCL list"))
  end

  it "returns 404 for an unknown lesson" do
    get("/grammar/999")

    expect(response).to(have_http_status(:not_found))
  end
end
