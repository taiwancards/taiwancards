# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reader" do
  let!(:word) { create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"}) }

  def text_for(user, attrs = {})
    ReadingText.create!(
      {user:, kind: :article, title: "My text", body: "我去學校", source: "manual"}.merge(attrs)
    )
  end

  it "saves a pasted text, normalizing simplified characters" do
    post("/reader", params: {reading_text: {title: "News", body: "我去学校"}})

    text = ReadingText.last
    expect(text.body).to(eq("我去學校"))
    expect(text.changed_characters).to(include("学"))
    expect(response).to(redirect_to(reader_text_path(text)))
  end

  it "renders the text as tappable tokens" do
    text = text_for(@authenticated_user)

    get("/reader/#{text.id}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("學校"))
    expect(response.body).to(include("data-analyzer-target=\"word\""))
  end

  it "turns a text into a desk" do
    text = text_for(@authenticated_user)

    expect { post("/reader/#{text.id}/desk") }.to(change(Collection.where(kind: :manual), :count).by(1))

    expect(text.reload.collection).to(be_present)
    expect(text.collection.lexemes).to(include(word))
  end

  it "hides restricted songs from a user without access" do
    text_for(nil, kind: :song, title: "SecretSong", restricted: true, source: "lrclib")

    get("/reader")

    expect(response.body).not_to(include("SecretSong"))
  end

  it "shows restricted songs to a user with access" do
    text_for(nil, kind: :song, title: "SecretSong", restricted: true, source: "lrclib")
    sign_in(create(:user, restricted_content: true))

    get("/reader")

    expect(response.body).to(include("SecretSong"))
  end

  it "deletes a text" do
    text = text_for(@authenticated_user)

    expect { delete("/reader/#{text.id}") }.to(change(ReadingText, :count).by(-1))
  end
end
