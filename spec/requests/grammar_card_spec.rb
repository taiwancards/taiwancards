# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Grammar cards in a sitting" do
  it "renders the pattern, its formula and the explanation on the back" do
    lexeme = create(
      :lexeme,
      kind: :grammar,
      text: "繫動詞",
      meanings: {"en" => "是 — the verb \"to be\" between two nouns"},
      data: {"tbcl_grade" => 1, "grammar_slug" => "shi", "head" => "是", "facets" => ["recognition"]}
    )
    deck = Collection.create!(
      kind: :manual,
      name: "Grammar",
      user: current_user,
      settings: {"facets" => %w[recognition]}
    )
    deck.add_lexeme(lexeme)

    get(study_path(mode: "collection", collection_id: deck.id))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("the verb &quot;to be&quot;"))
    expect(response.body).to(include("/grammar/shi"))
    expect(response.body).to(include("A + 是 + B"))
  end

  it "still renders when the lesson text is not on disk" do
    lexeme = create(
      :lexeme,
      kind: :grammar,
      text: "未知語法點",
      meanings: {"en" => "an unknown pattern"},
      data: {"tbcl_grade" => 1, "grammar_slug" => "no-such-slug", "head" => "未", "facets" => ["recognition"]}
    )
    deck = Collection.create!(
      kind: :manual,
      name: "Grammar",
      user: current_user,
      settings: {"facets" => %w[recognition]}
    )
    deck.add_lexeme(lexeme)

    get(study_path(mode: "collection", collection_id: deck.id))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("未"))
  end
end
