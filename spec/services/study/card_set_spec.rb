# frozen_string_literal: true

require "rails_helper"

RSpec.describe Study::CardSet do
  let(:user) { create(:user) }

  before { Current.user = user }
  after { Current.reset }

  def lexeme_ids(tokens)
    tokens.map { |token| token.split(":").first.to_i }
  end

  describe "fresh pool" do
    it "includes words, not only characters" do
      create(:lexeme, :character, text: "字", data: {"freq_rank" => 5})
      word = create(:lexeme, kind: :word, text: "詞語", data: {"freq_rank" => 1})

      tokens = described_class.new.build(mode: "daily", size: 4)

      expect(lexeme_ids(tokens)).to(include(word.id))
    end
  end

  describe "desk mode" do
    it "activates fresh collection members and returns swipe tokens" do
      word = create(:lexeme, kind: :word, text: "書本")
      desk = Collection.create!(kind: :manual, name: "D", user:)
      desk.add_lexeme(word)

      tokens = described_class.new.build(mode: "desk", collection: desk)

      expect(lexeme_ids(tokens)).to(include(word.id))
    end

    it "honors facet toggles, emitting only the enabled swipe facets" do
      word = create(:lexeme, kind: :word, text: "字詞")
      desk = Collection.create!(kind: :manual, name: "D", user:, settings: {"facets" => ["recognition"]})
      desk.add_lexeme(word)

      tokens = described_class.new.build(mode: "desk", collection: desk)

      expect(tokens.map { |token| token.split(":").last }.uniq).to(eq(["recognition"]))
    end

    it "includes tone and handwriting cards when the desk opts into them" do
      word = create(:lexeme, kind: :word, text: "字詞")
      desk = Collection.create!(
        kind: :manual,
        name: "D",
        user:,
        settings: {"facets" => %w[recognition tone writing]}
      )
      desk.add_lexeme(word)

      tokens = described_class.new.build(mode: "desk", collection: desk)

      expect(tokens.map { |token| token.split(":").last }.uniq).to(eq(%w[recognition tone writing]))
    end

    it "keeps tone and handwriting out of the default daily session" do
      create(:lexeme, kind: :word, text: "詞語", data: {"freq_rank" => 1})

      tokens = described_class.new.build(mode: "daily", size: 4)

      facets = tokens.map { |token| token.split(":").last }.uniq
      expect(facets).to(all(be_in(described_class::SWIPE_FACETS)))
      expect(facets).to(include("recognition"))
      expect(facets).not_to(include("tone", "writing"))
    end
  end
end
