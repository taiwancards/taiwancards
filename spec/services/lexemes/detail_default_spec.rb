# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::DetailDefault do
  let(:user) { create(:user) }

  def novice_collection(tag, words)
    collection = Collection.create!(kind: :tocfl, name: "TOCFL #{tag}", level_tag: tag, position: 0)
    words.each_with_index { |word, index| collection.add_lexeme(word, position: index) }
    collection.update!(items_count: words.size)
    collection
  end

  def learn(word)
    LexemeMemory.create!(lexeme: word, user:, facet: :recognition, state: :review, activated_at: Time.current)
  end

  it "starts a signed-out visitor on the full view" do
    expect(described_class.new(nil).call).to(eq("full"))
  end

  it "starts a beginner on the brief view" do
    novice_collection("Novice1", create_list(:lexeme, 3))

    expect(described_class.new(user).call).to(eq("brief"))
  end

  it "starts someone past Novice on the full view" do
    novice_collection("Novice1", create_list(:lexeme, 3))
    user.level = "4"
    user.save!

    expect(described_class.new(user).call).to(eq("full"))
  end

  it "switches to the full view once two thirds of Novice are known" do
    words = create_list(:lexeme, 3)
    novice_collection("Novice1", words)
    words.first(2).each { |word| learn(word) }

    expect(described_class.new(user).call).to(eq("full"))
  end

  it "stays brief while less than two thirds of Novice are known" do
    words = create_list(:lexeme, 3)
    novice_collection("Novice1", words)
    learn(words.first)

    expect(described_class.new(user).call).to(eq("brief"))
  end

  it "counts a word once however many facets of it are in review" do
    words = create_list(:lexeme, 3)
    novice_collection("Novice1", words)
    learn(words.first)
    LexemeMemory.create!(
      lexeme: words.first,
      user:,
      facet: :production,
      state: :review,
      activated_at: Time.current
    )

    expect(described_class.new(user).call).to(eq("brief"))
  end
end
