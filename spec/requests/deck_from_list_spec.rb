# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Deck from a pasted list" do
  let!(:easy) do
    create(
      :lexeme,
      kind: :word,
      text: "學校",
      meanings: {"en" => "school", "ru" => "школа"},
      score: 10
    )
  end

  let!(:hard) do
    create(:lexeme, kind: :collocation, text: "一毛不拔", meanings: {"en" => "stingy"}, score: 900)
  end

  before { sign_in(create(:user)) }

  it "resolves a comma-separated list, orders it easiest first and reports duplicates" do
    post("/desks/preview", params: {name: "Мой список", text: "一毛不拔, 學校，學校"})
    expect(response).to(have_http_status(:ok))
    expect(response.body.index("學校")).to(be < response.body.index("一毛不拔"))
    expect(response.body).to(include(I18n.t("desks.stat_duplicates", count: 1)))
  end

  it "reports what is not in the dictionary" do
    post("/desks/preview", params: {text: "學校\n不存在的詞"})
    expect(response.body).to(include(I18n.t("desks.missing_title")))
    expect(response.body).to(include("不存在的詞"))
  end

  it "accepts an uploaded file" do
    file = Rack::Test::UploadedFile.new(
      StringIO.new("學校\n一毛不拔\n"),
      "text/plain",
      original_filename: "list.txt"
    )
    post("/desks/preview", params: {file:})
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("學校"))
    expect(response.body).to(include("一毛不拔"))
  end

  it "marks the whole list as already familiar" do
    expect do
      post("/desks/known", params: {lexeme_ids: [easy.id, hard.id]})
    end
      .to(change(LexemeMemory.state_review, :count).by_at_least(1))
    expect(response).to(redirect_to(desks_path))
  end
end
