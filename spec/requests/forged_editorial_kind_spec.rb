# frozen_string_literal: true

require "rails_helper"

RSpec.describe "A learner's deck carrying an editorial kind", :no_auth do
  def forged(kind, text, data)
    deck = create(:user).collections.create!(kind: :manual, name: "Mine")
    deck.add_lexemes([create(:lexeme, text:, data:).id])
    deck.update_column(:kind, Collection.kinds.fetch(kind.to_s))
  end

  def curated(kind, text, data)
    Collection.create!(kind:, name: kind.to_s).add_lexemes([create(:lexeme, text:, data:).id])
  end

  it "never stands in for the everyday collection" do
    placed = {"tier" => 1, "placements" => [{"domain" => "food", "tag" => "drinks"}]}
    forged(:everyday, "偽造詞", placed)
    curated(:everyday, "珍奶", placed)

    get("/en/everyday")

    expect(response.body).to(include("珍奶"))
    expect(response.body).not_to(include("偽造詞"))
  end

  it "never stands in for the board games collection" do
    forged(:games, "偽造詞", {"game" => {"name" => "mahjong", "category" => "game"}})
    curated(:games, "碰", {"game" => {"name" => "mahjong", "category" => "game"}})

    get("/en/games")

    expect(response.body).to(include("碰"))
    expect(response.body).not_to(include("偽造詞"))
  end

  it "never becomes a TOCFL level of a study plan" do
    forged(:tocfl, "偽造詞", {})
    Collection.find_by(name: "Mine").update_columns(level_tag: "B1", position: 0)
    plan = StudyPlan.new(user: create(:user), target_level: "B1", target_date: Date.current + 30)

    expect(Study::PlanCalculator.new(plan).collections).to(be_empty)
  end
end
