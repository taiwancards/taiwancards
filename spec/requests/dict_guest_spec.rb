# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The dictionary for a guest", :no_auth do
  let!(:word) { create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"}) }

  it "sends a guest who tries to add an entry to sign in and stores nothing" do
    expect { post("/en/dict/#{CGI.escape("學校")}/activate") }.not_to(change(LexemeMemory, :count))

    expect(response).to(redirect_to(login_path))
  end

  it "still opens the list and an entry for a guest" do
    get("/en/dict")
    expect(response).to(have_http_status(:ok))

    get("/en/dict/#{CGI.escape("學校")}")
    expect(response).to(have_http_status(:ok))
  end

  it "ignores a level that is not a TOCFL list" do
    get("/en/dict", params: {level: "x" * 500})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("學校"))
  end

  it "searches a level list that belongs to the editorial collections" do
    other = create(:lexeme, kind: :word, text: "老師")
    forged = create(:user).collections.create!(kind: :manual, name: "Mine", level_tag: "Novice1")
    forged.add_lexemes([other.id])
    forged.update_column(:kind, Collection.kinds[:tocfl])
    Collection.create!(kind: :tocfl, name: "Novice 1", level_tag: "Novice1").add_lexemes([word.id])

    get("/en/dict", params: {level: "Novice1"})

    expect(response.body).to(include("學校"))
    expect(response.body).not_to(include("老師"))
  end
end
