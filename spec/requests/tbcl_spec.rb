# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TBCL word lists" do
  let!(:third) do
    create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"}, data: {"tbcl_grade" => "3"})
  end

  let!(:seventh) do
    create(:lexeme, kind: :word, text: "罕見", meanings: {"en" => "rare"}, data: {"tbcl_grade" => "7"})
  end

  it "lists every grade with its size" do
    get("/tbcl")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("/tbcl/3"))
    expect(response.body).to(include("/tbcl/7"))
  end

  it "shows only the entries of the requested grade" do
    get("/tbcl/3")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("學校"))
    expect(response.body).not_to(include("罕見"))
  end

  it "links entries to the unified dictionary" do
    get("/tbcl/3")
    expect(response.body).to(include(dict_entry_path(text: "學校")))
  end

  it "rejects a grade outside the scale" do
    get("/tbcl/9")
    expect(response).to(have_http_status(:not_found))
  end

  it "rings the marked entry so the badge that linked here points at it" do
    get("/tbcl/3?mark=%E5%AD%B8%E6%A0%A1")
    expect(response.body).to(include("ring-2 ring-brand"))
    expect(response.body).to(include("id=\"mark\""))
  end

  it "opens the page the marked entry sits on" do
    stub_const("TbclController::PER_PAGE", 1)
    create(
      :lexeme,
      kind: :word,
      text: "圖書館",
      meanings: {"en" => "library"},
      data: {"tbcl_grade" => "3", "freq_rank" => "900"}
    )

    get("/tbcl/3?mark=%E5%AD%B8%E6%A0%A1")
    expect(response.body).to(include("學校"))
    expect(response.body).not_to(include("圖書館"))
  end

  it "ignores a mark that names nothing on the list" do
    get("/tbcl/3?mark=%E7%BD%95%E8%A6%8B")
    expect(response).to(have_http_status(:ok))
    expect(response.body).not_to(include("ring-2 ring-brand"))
  end
end
