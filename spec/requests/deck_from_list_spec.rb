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

  it "offers every distinct word in the list exactly once" do
    post("/desks/preview", params: {name: "Мой список", text: "一毛不拔, 學校，學校"})

    expect(response).to(have_http_status(:ok))
    expect(preview_candidates).to(contain_exactly("學校", "一毛不拔"))
  end

  it "shows a word that is not in the dictionary without offering it as a card" do
    post("/desks/preview", params: {text: "學校\n不存在的詞"})

    expect(preview_candidates).to(include("學校"))
    expect(preview_candidates).not_to(include("不存在的詞"))
  end

  it "accepts an uploaded file" do
    file = Rack::Test::UploadedFile.new(
      StringIO.new("學校\n一毛不拔\n"),
      "text/plain",
      original_filename: "list.txt"
    )
    post("/desks/preview", params: {file:})

    expect(response).to(have_http_status(:ok))
    expect(preview_candidates).to(contain_exactly("學校", "一毛不拔"))
  end

  it "builds the deck from the single packed field the preview posts back" do
    expect { post("/desks", params: {selection: Collections::Selection.pack([easy.id]), name: "Picked"}) }
      .to(change(Collection, :count).by(1))

    expect(Collection.last.lexemes.map(&:text)).to(eq(["學校"]))
  end

  it "sends one parameter however many cards are picked, so no request limit is hit" do
    packed = Collections::Selection.pack([easy.id, hard.id])

    expect(packed.count(",")).to(eq(1))
    expect(Collections::Selection.unpack(packed, limit: 10)).to(eq([easy.id, hard.id]))
  end

  it "drops ids that point at nothing instead of failing" do
    post("/desks", params: {selection: Collections::Selection.pack([easy.id, 999_999_999]), name: "Partly"})

    expect(Collection.find_by(name: "Partly").lexemes.map(&:text)).to(eq(["學校"]))
  end

  it "marks the whole list as already familiar" do
    expect do
      post("/desks/known", params: {lexeme_ids: [easy.id, hard.id]})
    end
      .to(change(LexemeMemory.state_review, :count).by_at_least(1))
    expect(response).to(redirect_to(desks_path))
  end
end
