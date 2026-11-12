# frozen_string_literal: true

require "rails_helper"

RSpec.describe Progress::Import, :aggregate_failures do
  let(:user) { create(:user, prefs: {"goal" => "guided", "signup_from" => "landing"}) }
  let!(:word) { create(:lexeme, kind: :word, text: "學校") }
  let!(:secret) { create(:lexeme, kind: :phrase, text: "授權句子", restricted: true) }

  def import(payload) = described_class.new(user).call(payload)

  def deck_row(**overrides)
    {
      "name" => "Мои слова",
      "kind" => "manual",
      "items" => [{"kind" => "word", "text" => "學校", "position" => 0}]
    }.merge(overrides.transform_keys(&:to_s))
  end

  it "never grants restricted content through the settings section" do
    import("settings" => {"restricted_content" => true, "prefs" => {"level" => "3"}})

    expect(user.reload.restricted_access?).to(be(false))
    expect(user.level).to(eq("3"))
  end

  it "keeps the account's own signup attribution" do
    import("settings" => {"prefs" => {"signup_from" => "forged"}})

    expect(user.reload.signup_from).to(eq("landing"))
  end

  it "ignores a prefs section that is not an object" do
    import("settings" => {"prefs" => ["level", "7"]})

    expect(user.reload.prefs).to(include("goal" => "guided"))
  end

  it "imports every deck as a plain deck whatever kind the file claims" do
    expect { import("collections" => [deck_row(kind: "tocfl", level_tag: "Novice1")]) }.not_to(raise_error)

    deck = Collection.find_by(user:)
    expect(deck.kind).to(eq("manual"))
    expect(Collection.curated.where(kind: :tocfl)).to(be_empty)
    expect(deck.lexemes).to(contain_exactly(word))
  end

  it "keeps the deck's cards in the order of the file and counts them" do
    others = %w[水 火 木].map { |text| create(:lexeme, kind: :character, text:) }
    items = others.reverse.map { |lexeme| {"kind" => "character", "text" => lexeme.text} }

    import("collections" => [deck_row(items:)])

    deck = Collection.find_by(user:)
    expect(deck.ordered_lexeme_ids).to(eq(others.reverse.map(&:id)))
    expect(deck.items_count).to(eq(3))
  end

  it "stops filling a deck at the deck limit" do
    stub_const("Collection::MAX_ITEMS", 2)
    others = %w[水 火 木].map { |text| create(:lexeme, kind: :character, text:) }

    import("collections" => [deck_row(items: others.map { |lexeme| {"kind" => "character", "text" => lexeme.text} })])

    expect(Collection.find_by(user:).collection_items.count).to(eq(2))
  end

  it "leaves out restricted entries for an account without access" do
    secret_row = {"kind" => "phrase", "text" => secret.text}

    counts = import(
      "memories" => [secret_row.merge("facet" => "recognition", "state" => "review")],
      "collections" => [deck_row(items: [secret_row, {"kind" => "word", "text" => "學校"}])]
    )

    expect(LexemeMemory.owned_by(user).where(lexeme: secret)).to(be_empty)
    expect(Collection.find_by(user:).lexemes).to(contain_exactly(word))
    expect(counts[:skipped]).to(eq(1))
  end

  it "keeps restricted entries for an account cleared for them" do
    user.update!(restricted_content: true)

    import("collections" => [deck_row(items: [{"kind" => "phrase", "text" => secret.text}])])

    expect(Collection.find_by(user:).lexemes).to(contain_exactly(secret))
  end

  it "turns an editorial reading text kind into a plain article" do
    import(
      "reading_texts" => [
        {"title" => "Forged", "body" => "我今天去學校。", "kind" => "story"},
        {"title" => "Graded", "body" => "我去學校。", "kind" => "graded"}
      ]
    )

    expect(ReadingText.where(user:).pluck(:title, :kind)).to(contain_exactly(%w[Forged article], %w[Graded graded]))
  end
end
