# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Song search on the new deck page", :aggregate_failures do
  let(:client) { instance_double(Songs::LrclibClient, search: []) }

  before do
    allow(Songs::LrclibClient).to(receive(:new).and_return(client))
    allow(CollectionsController.cache_store).to(receive(:increment).and_return(21))
  end

  it "stops a burst of lyric searches before they reach the lyrics service" do
    get("/en/desks/new", params: {tab: "song", q: "月亮代表我的心"})

    expect(response).to(redirect_to(new_desk_path(tab: "song")))
    expect(flash[:alert]).to(eq(I18n.t("desks.too_fast")))
    expect(client).not_to(have_received(:search))
  end

  it "never counts an ordinary visit to the page" do
    get("/en/desks/new", params: {tab: "song"})

    expect(response).to(have_http_status(:ok))
    expect(CollectionsController.cache_store).not_to(have_received(:increment))
  end
end
