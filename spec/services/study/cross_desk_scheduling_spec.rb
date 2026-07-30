# frozen_string_literal: true

require "rails_helper"

RSpec.describe Study::CardSet do
  let(:user) { create(:user) }
  let!(:shared) { create(:lexeme, text: "車站", readings: {"zhuyin" => "ㄔㄜ ㄓㄢˋ"}) }
  let!(:only_in_b) { create(:lexeme, text: "捷運", readings: {"zhuyin" => "ㄐㄧㄝˊ ㄩㄣˋ"}) }

  before { Current.user = user }
  after { Current.reset }

  def desk(name, lexemes)
    collection = Collection.create!(kind: :manual, name:, user:)
    lexemes.each { |lexeme| collection.add_lexeme(lexeme) }
    collection
  end

  def studied_today!(lexeme, next_due: 5.days.from_now)
    Lexemes::Activator.new.call(lexeme)
    LexemeMemory
      .owned_by(user)
      .where(lexeme:)
      .update_all(state: LexemeMemory.states[:review], stability: 5.0, due_at: next_due)
  end

  it "does not resurface a word in a second desk when FSRS says it is not due yet" do
    desk_a = desk("Song lyrics", [shared])
    desk_b = desk("Newspaper", [shared, only_in_b])

    Study::CardSet.new.build(mode: "desk", collection: desk_a)
    studied_today!(shared)

    tokens = Study::CardSet.new.build(mode: "desk", collection: desk_b)
    lexeme_ids = tokens.map { |token| token.split(":").first.to_i }.uniq

    expect(lexeme_ids).not_to(include(shared.id))
    expect(lexeme_ids).to(include(only_in_b.id))
  end

  it "brings the shared word back once it actually falls due" do
    desk_b = desk("Newspaper", [shared, only_in_b])
    studied_today!(shared, next_due: 1.minute.ago)

    tokens = Study::CardSet.new.build(mode: "desk", collection: desk_b)
    lexeme_ids = tokens.map { |token| token.split(":").first.to_i }.uniq

    expect(lexeme_ids).to(include(shared.id))
  end

  it "keeps one memory per word no matter how many desks contain it" do
    desk("Song lyrics", [shared])
    desk("Newspaper", [shared])

    Lexemes::Activator.new.call(shared)

    expect(LexemeMemory.owned_by(user).where(lexeme: shared).distinct.count(:facet))
      .to(eq(LexemeMemory.owned_by(user).where(lexeme: shared).count))
  end
end
