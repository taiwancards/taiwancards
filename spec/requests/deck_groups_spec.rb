# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Deck groups" do
  let!(:school) { create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"}) }
  let!(:book) { create(:lexeme, kind: :word, text: "課本", meanings: {"en" => "textbook"}) }

  def deck(name)
    Collection.create!(kind: :manual, name:, user: current_user)
  end

  it "creates a group and puts the chosen decks in it" do
    first = deck("Songs")
    second = deck("News")

    post("/groups", params: {name: "Reading", deck_ids: [first.id, second.id]})

    group = CollectionGroup.owned_by(current_user).last
    expect(group.name).to(eq("Reading"))
    expect(group.collections_count).to(eq(2))
    expect(response).to(redirect_to(group_path(group)))
  end

  it "lets one deck sit in several groups at once" do
    shared = deck("Songs")
    post("/groups", params: {name: "Music", deck_ids: [shared.id]})
    post("/groups", params: {name: "Favourites", deck_ids: [shared.id]})

    expect(shared.reload.groups.map(&:name)).to(contain_exactly("Music", "Favourites"))
  end

  it "adds and removes decks without touching the decks themselves" do
    group = CollectionGroup.create!(user: current_user, name: "Reading")
    target = deck("Songs")
    target.add_lexemes([school.id])

    post("/groups/#{group.id}/decks", params: {deck_ids: [target.id]})
    expect(group.reload.collections_count).to(eq(1))

    delete("/groups/#{group.id}/decks/#{target.id}")
    expect(group.reload.collections_count).to(eq(0))
    expect(Collection.find_by(id: target.id)&.lexemes&.map(&:text)).to(eq(["學校"]))
  end

  it "keeps the decks when the group goes" do
    group = CollectionGroup.create!(user: current_user, name: "Reading")
    kept = deck("Songs")
    group.add_collections([kept.id])

    delete("/groups/#{group.id}")

    expect(CollectionGroup.find_by(id: group.id)).to(be_nil)
    expect(Collection.find_by(id: kept.id)).to(be_present)
  end

  it "refuses to take another person's deck into a group" do
    group = CollectionGroup.create!(user: current_user, name: "Reading")
    stranger = Collection.create!(kind: :manual, name: "Theirs", user: create(:user))

    post("/groups/#{group.id}/decks", params: {deck_ids: [stranger.id]})

    expect(group.reload.collections_count).to(eq(0))
  end

  it "returns not found for another person's group" do
    other = CollectionGroup.create!(user: create(:user), name: "Secret")

    get("/groups/#{other.id}")

    expect(response).to(have_http_status(:not_found))
  end

  it "reorders groups in one statement" do
    names = %w[A B C]
    groups = names.map { |name| CollectionGroup.create!(user: current_user, name:, position: names.index(name)) }

    post("/groups/reorder", params: {order: groups.reverse.map(&:id)})

    expect(CollectionGroup.owned_by(current_user).ordered.map(&:name)).to(eq(%w[C B A]))
  end

  it "reorders the decks inside a group" do
    group = CollectionGroup.create!(user: current_user, name: "Reading")
    first = deck("Songs")
    second = deck("News")
    group.add_collections([first.id, second.id])

    post("/groups/#{group.id}/reorder", params: {order: [second.id, first.id]})

    expect(group.collections.order(Arel.sql("collection_group_items.position")).map(&:name))
      .to(eq(%w[News Songs]))
  end

  it "reorders decks on the My decks screen" do
    first = deck("Songs")
    second = deck("News")

    post("/desks/reorder", params: {order: [second.id, first.id]})

    expect(Collection.desks_for(current_user).arranged.map(&:name)).to(eq(%w[News Songs]))
  end
end
