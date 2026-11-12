# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Aggregates cached for the editorial sections", :aggregate_failures, :no_auth do
  let(:cached) { {} }

  def plain?(value)
    case value
    when Hash
      value.default_proc.nil? && value.all? { |key, inner| plain?(key) && plain?(inner) }
    when Array
      value.all? { |inner| plain?(inner) }
    else
      [String, Integer, Float, NilClass].any? { |type| value.is_a?(type) }
    end
  end

  def collection_with(kind, rows)
    Collection.create!(kind:, name: kind.to_s).tap do |collection|
      collection.add_lexemes(rows.map { |text, data| create(:lexeme, text:, data:).id })
    end
  end

  before do
    allow(ContentCache).to(
      receive(:fetch).and_wrap_original do |original, *key, &block|
        original.call(*key, &block).tap { |value| cached[key.flatten.compact.join("/")] = value }
      end
    )
  end

  describe "the everyday section" do
    before do
      collection_with(
        :everyday,
        [
          [
            "珍奶",
            {"tier" => 1, "origin" => "abbreviation", "placements" => [{"domain" => "food", "tag" => "drinks"}]}
          ],
          ["雞排", {"tier" => 1, "origin" => "hokkien", "placements" => [{"domain" => "food", "tag" => "snacks"}]}],
          ["滷肉飯", {"tier" => 1, "origin" => "hokkien", "placements" => [{"domain" => "food", "tag" => "snacks"}]}]
        ]
      )
    end

    it "caches the landing samples per visibility as plain data" do
      get("/en/everyday")

      samples = cached.fetch("everyday/samples/#{Lexeme.visibility_key(nil)}")
      expect(samples).to(eq({"food" => %w[珍奶 雞排 滷肉飯]}))
      expect(plain?(samples)).to(be(true))
      expect { Marshal.dump(samples) }.not_to(raise_error)
    end

    it "caches the tags of an area per origin and visibility as plain data" do
      get("/en/everyday", params: {area: "food"})
      get("/en/everyday", params: {area: "food", origin: "hokkien"})

      expect(cached.fetch("everyday/tags/food//#{Lexeme.visibility_key(nil)}")).to(eq(%w[snacks drinks]))
      expect(cached.fetch("everyday/tags/food/hokkien/#{Lexeme.visibility_key(nil)}")).to(eq(%w[snacks]))
    end
  end

  describe "the board games section" do
    before do
      collection_with(
        :games,
        [
          ["碰", {"game" => {"name" => "mahjong", "category" => "game"}}],
          ["吃", {"game" => {"name" => "mahjong", "category" => "game"}}],
          ["將", {"game" => {"name" => "xiangqi", "category" => "game"}}]
        ]
      )
    end

    it "counts the entries per game in the database and caches the tally" do
      report = count_queries { get("/en/games") }

      expect(cached.fetch("games/counts/#{Lexeme.visibility_key(nil)}")).to(eq({"mahjong" => 2, "xiangqi" => 1}))
      expect(report.statements.grep(/GROUP BY lexemes\.data -> 'game' ->> 'name'/)).not_to(be_empty)
    end
  end

  describe "the idiom bands" do
    before do
      create(:lexeme, kind: :collocation, text: "一毛不拔", score: 100, data: {"chengyu" => true})
      create(:lexeme, kind: :collocation, text: "亂七八糟", score: 500, data: {"chengyu" => true})
    end

    it "keys the band edges by what the reader may see instead of asking for the latest edit" do
      report = count_queries { get("/en/chengyu", params: {band: "easy"}) }

      expect(cached).to(have_key("chengyu/band_edges/#{Lexeme.visibility_key(nil)}"))
      expect(report.statements.grep(/MAX\("lexemes"\."updated_at"\)/)).to(be_empty)
    end
  end
end
