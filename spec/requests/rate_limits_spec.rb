# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bursts of costly requests", :aggregate_failures do
  def over_the_limit = allow(ActionController::Base.cache_store).to(receive(:increment).and_return(1_000))

  def deck = Collection.create!(kind: :manual, name: "Mine", user: current_user)

  before { over_the_limit }

  it "stops a burst of word list previews on the new deck page" do
    post("/desks/preview", params: {text: "學校 老師"})

    expect(response).to(redirect_to(new_desk_path))
    expect(flash[:alert]).to(eq(I18n.t("desks.too_fast")))
  end

  it "stops a burst of song decks" do
    post("/desks/song", params: {id: "1"})

    expect(response).to(redirect_to(new_desk_path))
    expect(flash[:alert]).to(eq(I18n.t("desks.too_fast")))
  end

  it "stops a burst of imported files before one is read" do
    %w[/desks/import /desks/import/deck].each do |path|
      expect { post(path, params: {source: "pleco"}) }.not_to(change(Collection, :count))

      expect(response).to(redirect_to(new_desk_path(tab: "import")), path)
      expect(flash[:alert]).to(eq(I18n.t("desks.too_fast")), path)
    end
  end

  it "stops a burst of share links" do
    owned = deck

    expect { post("/desks/#{owned.id}/share") }.not_to(change(DeckShare, :count))
    expect(response).to(redirect_to(desks_path))
    expect(flash[:alert]).to(eq(I18n.t("shares.too_many")))
  end

  it "stops a burst of accepted shares" do
    owner = create(:user)
    share = Decks::Sharing.publish_deck(Collection.create!(kind: :manual, name: "Theirs", user: owner), user: owner)

    expect { post("/s/#{share.token}") }.not_to(change(Collection, :count))
    expect(share.reload.accepted_count).to(eq(0))
    expect(response).to(redirect_to(desks_path))
    expect(flash[:alert]).to(eq(I18n.t("shares.too_many")))
  end

  it "turns a burst of guessed share links away before any of them is looked up" do
    post("/s/no-such-token")

    expect(response).to(redirect_to(desks_path))
    expect(flash[:alert]).to(eq(I18n.t("shares.too_many")))
  end

  it "stops a burst of texts pasted into the reader" do
    expect { post("/reader", params: {reading_text: {body: "我們學校很大。"}}) }.not_to(
      change(ReadingText, :count)
    )
    expect(response).to(redirect_to(new_reader_text_path))
    expect(flash[:alert]).to(eq(I18n.t("desks.too_fast")))
  end
end
