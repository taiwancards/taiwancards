# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Quick add" do
  let!(:word) { create(:lexeme, kind: :word, text: "書", meanings: {"en" => "book"}) }

  it "bootstraps a first desk when the user has none" do
    expect do
      post("/quick_add", params: {lexeme_id: word.id})
    end
      .to(change(Collection.desks_for(@authenticated_user), :count).by(1))

    desk = Collection.desks_for(@authenticated_user).last
    expect(desk.lexemes).to(include(word))
  end

  it "adds to the most recently used desk by default" do
    old = Collection.create!(kind: :manual, name: "Old", user: @authenticated_user, last_used_at: 2.days.ago)
    recent = Collection.create!(
      kind: :manual,
      name: "Recent",
      user: @authenticated_user,
      last_used_at: 1.minute.ago
    )

    post("/quick_add", params: {lexeme_id: word.id})

    expect(recent.reload.lexemes).to(include(word))
    expect(old.reload.lexemes).not_to(include(word))
  end

  it "adds to an explicitly chosen desk" do
    target = Collection.create!(kind: :manual, name: "Target", user: @authenticated_user)

    post("/quick_add", params: {lexeme_id: word.id, collection_id: target.id})

    expect(target.reload.lexemes).to(include(word))
  end
end
