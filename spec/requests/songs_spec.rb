# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Song lyrics" do
  let(:row) do
    {
      "id" => 1,
      "track" => "2012",
      "artist" => "五月天",
      "album" => "第二人生",
      "plain" => "再没有時間",
      "synced" => "[00:01.0] 再没有時間"
    }
  end

  before { create(:lexeme, kind: :word, text: "時間", meanings: {"en" => "time"}) }

  it "lets any signed-in person search for a song" do
    allow_any_instance_of(Songs::LrclibClient).to(receive(:search).and_return([row]))

    get(new_desk_path, params: {tab: "song", q: "五月天"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("五月天"))
  end

  it "turns the lyrics into a word list without keeping the lyrics" do
    allow_any_instance_of(Songs::LrclibClient).to(receive(:fetch).and_return(row))

    expect { post(desk_song_path, params: {lrclib_id: 1}) }.not_to(change(ReadingText, :count))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("時間"))
    expect(ReadingText.where("body ILIKE ?", "%時間%")).to(be_empty)
  end

  it "reports a friendly message when the lyrics service is down" do
    allow_any_instance_of(Songs::LrclibClient).to(receive(:fetch).and_return(nil))

    post(desk_song_path, params: {lrclib_id: 1, q: "五月天"})

    expect(response).to(redirect_to(new_desk_path(tab: "song", q: "五月天")))
    expect(flash[:alert]).to(eq(I18n.t("songs.error_network")))
  end
end
