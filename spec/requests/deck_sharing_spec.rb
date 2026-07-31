# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Deck sharing" do
  let(:owner) { create(:user) }
  let!(:school) { create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"}) }
  let!(:book) { create(:lexeme, kind: :word, text: "課本", meanings: {"en" => "textbook"}) }

  def deck_for(user, name, lexemes)
    deck = Collection.create!(kind: :manual, name:, user:, settings: {"facets" => %w[recognition]})
    deck.add_lexemes(lexemes.map(&:id))
    deck
  end

  def share_of(deck, user)
    Decks::Sharing.publish_deck(deck, user:)
  end

  it "hands the recipient an independent copy, not a reference" do
    deck = deck_for(owner, "Trip", [school, book])
    share = share_of(deck, owner)

    post("/s/#{share.token}")

    copy = Collection.desks_for(current_user).last
    expect(copy.lexemes.map(&:text)).to(contain_exactly("學校", "課本"))
    expect(copy.id).not_to(eq(deck.id))
    expect(response).to(redirect_to(my_desk_path(copy)))
  end

  it "leaves the copy untouched when the sharer renames, empties or deletes the original" do
    deck = deck_for(owner, "Trip", [school, book])
    share = share_of(deck, owner)
    post("/s/#{share.token}")
    copy = Collection.desks_for(current_user).last

    deck.update!(name: "Renamed")
    deck.remove_lexemes([school.id])
    deck.destroy!

    expect(copy.reload.name).to(eq("Trip"))
    expect(copy.lexemes.map(&:text)).to(contain_exactly("學校", "課本"))
    expect(DeckShare.find_live(share.token)).to(be_present)
  end

  it "carries the drilled facets across" do
    share = share_of(deck_for(owner, "Facets", [school]), owner)

    post("/s/#{share.token}")

    expect(Collection.desks_for(current_user).last.study_facets).to(eq(%w[recognition]))
  end

  it "copies a whole group and the decks inside it" do
    first = deck_for(owner, "Songs", [school])
    second = deck_for(owner, "News", [book])
    group = CollectionGroup.create!(user: owner, name: "Reading")
    group.add_collections([first.id, second.id])
    share = Decks::Sharing.publish_group(group, user: owner)

    post("/s/#{share.token}")

    copied = CollectionGroup.owned_by(current_user).last
    expect(copied.name).to(eq("Reading"))
    expect(copied.collections.map(&:name)).to(contain_exactly("Songs", "News"))
    expect(Collection.desks_for(current_user).count).to(eq(2))
  end

  it "reports the overlap with what the recipient already has" do
    Collection.create!(kind: :manual, name: "Mine", user: current_user).add_lexemes([school.id])
    share = share_of(deck_for(owner, "Trip", [school, book]), owner)

    get("/s/#{share.token}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("shares.fresh", count: 1)))
  end

  it "copies only what is new when asked to" do
    Collection.create!(kind: :manual, name: "Mine", user: current_user).add_lexemes([school.id])
    share = share_of(deck_for(owner, "Trip", [school, book]), owner)

    post("/s/#{share.token}", params: {only_new: 1})

    expect(Collection.desks_for(current_user).last.lexemes.map(&:text)).to(eq(["課本"]))
  end

  it "says nothing was copied when the recipient already has all of it" do
    Collection.create!(kind: :manual, name: "Mine", user: current_user).add_lexemes([school.id])
    share = share_of(deck_for(owner, "Trip", [school]), owner)

    post("/s/#{share.token}", params: {only_new: 1})

    expect(response).to(redirect_to(desks_path))
    expect(flash[:alert]).to(eq(I18n.t("shares.nothing_copied")))
  end

  it "stops serving a revoked link" do
    share = share_of(deck_for(owner, "Trip", [school]), owner)
    share.revoke!

    get("/s/#{share.token}")

    expect(response).to(have_http_status(:not_found))
  end

  it "stops serving an expired link" do
    share = share_of(deck_for(owner, "Trip", [school]), owner)
    share.update!(expires_at: 1.minute.ago)

    get("/s/#{share.token}")

    expect(response).to(have_http_status(:not_found))
  end

  it "lets only the owner revoke" do
    share = share_of(deck_for(owner, "Trip", [school]), owner)

    delete("/shares/#{share.token}")

    expect(response).to(have_http_status(:not_found))
    expect(share.reload).not_to(be_revoked)
  end

  it "survives the dictionary being rebuilt under different ids" do
    share = share_of(deck_for(owner, "Trip", [school]), owner)
    expect(share.payload["decks"].first["items"]).to(eq([["word", "學校"]]))

    Collection.delete_all
    CollectionItem.delete_all
    school.destroy!
    rebuilt = create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"})

    post("/s/#{share.token}")

    expect(Collection.desks_for(current_user).last.lexeme_ids).to(eq([rebuilt.id]))
  end

  it "records how many people took the deck" do
    share = share_of(deck_for(owner, "Trip", [school]), owner)

    post("/s/#{share.token}")

    expect(share.reload.accepted_count).to(eq(1))
  end
end
