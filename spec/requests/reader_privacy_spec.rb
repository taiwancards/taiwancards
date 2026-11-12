# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reader privacy" do
  let!(:word) { create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"}) }
  let(:author) { create(:user) }
  let(:stranger) { create(:user) }

  def pasted_by(user, attrs = {})
    ReadingText.create!(
      {user:, kind: :article, title: "Diary of #{user.id}", body: "我去學校", source: "manual"}.merge(attrs)
    )
  end

  def library_text(attrs = {})
    ReadingText.create!({kind: :news, title: "Shared news", body: "我去學校", source: "pts"}.merge(attrs))
  end

  it "keeps a pasted text out of another account's reader list" do
    text = pasted_by(author)
    sign_in(stranger)

    get("/reader")

    expect(response).to(have_http_status(:ok))
    expect(response.body).not_to(include(text.title))
  end

  it "answers not found when another account opens a pasted text" do
    text = pasted_by(author)
    sign_in(stranger)

    get("/reader/#{text.id}")

    expect(response).to(have_http_status(:not_found))
    expect(response.body).not_to(include(text.title))
  end

  it "does not let another account delete a pasted text" do
    text = pasted_by(author)
    sign_in(stranger)

    delete("/reader/#{text.id}")

    expect(response).to(have_http_status(:not_found))
    expect(ReadingText.exists?(text.id)).to(be(true))
  end

  it "does not let another account build a deck from a pasted text" do
    text = pasted_by(author)
    sign_in(stranger)

    expect { post("/reader/#{text.id}/desk") }.not_to(change(Collection, :count))

    expect(response).to(have_http_status(:not_found))
    expect(text.reload.collection).to(be_nil)
  end

  it "still lets the author list, open, turn into a deck and delete the text" do
    text = pasted_by(author)
    sign_in(author)

    get("/reader")
    expect(response.body).to(include(text.title))

    get("/reader/#{text.id}")
    expect(response).to(have_http_status(:ok))

    post("/reader/#{text.id}/desk")
    expect(text.reload.collection.user).to(eq(author))

    expect { delete("/reader/#{text.id}") }.to(change(ReadingText, :count).by(-1))
  end

  it "shows the shared library to every account" do
    text = library_text
    sign_in(stranger)

    get("/reader")
    expect(response.body).to(include(text.title))

    get("/reader/#{text.id}")
    expect(response).to(have_http_status(:ok))
  end

  it "does not let a learner delete a text from the shared library" do
    text = library_text
    sign_in(stranger)

    delete("/reader/#{text.id}")

    expect(response).to(have_http_status(:not_found))
    expect(ReadingText.exists?(text.id)).to(be(true))
  end

  it "lets the admin prune a text from the shared library" do
    text = library_text
    sign_in(create(:user, :admin))

    expect { delete("/reader/#{text.id}") }.to(change(ReadingText, :count).by(-1))
  end

  it "builds a learner a private deck from a library text without tying it to the shared text" do
    text = library_text
    sign_in(stranger)

    expect { post("/reader/#{text.id}/desk") }.to(change(Collection.where(user: stranger), :count).by(1))

    expect(text.reload.collection).to(be_nil)
  end

  it "refuses a pasted text longer than a deck preview can read" do
    sign_in(author)
    body = "我" * (Collections::TextPreview::MAX_CHARS + 1)

    expect { post("/reader", params: {reading_text: {title: "Novel", body:}}) }.not_to(change(ReadingText, :count))

    expect(response).to(redirect_to(new_reader_text_path))
  end

  it "accepts a pasted text right at the limit" do
    sign_in(author)
    body = "我" * Collections::TextPreview::MAX_CHARS

    expect { post("/reader", params: {reading_text: {title: "Long", body:}}) }.to(change(ReadingText, :count).by(1))
  end

  it "leaves the length of an editorial text to the code that imports it" do
    text = library_text(body: "我" * (Collections::TextPreview::MAX_CHARS + 1))

    expect(text).to(be_persisted)
  end

  it "does not activate a word the account is not licensed to see" do
    hidden = create(:lexeme, kind: :word, text: "秘密", restricted: true)
    sign_in(stranger)

    post("/reader/activate", params: {lexeme_id: hidden.id})

    expect(response).to(have_http_status(:not_found))
    expect(LexemeMemory.owned_by(stranger).where(lexeme: hidden)).to(be_empty)
  end
end
