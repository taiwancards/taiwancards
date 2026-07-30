# frozen_string_literal: true

require "rails_helper"

RSpec.describe Collections::DeskBuilder do
  let(:user) { create(:user) }

  before { Current.user = user }
  after { Current.reset }

  it "builds an owned manual desk from selected lexemes and activates them" do
    word = create(:lexeme, kind: :word, text: "學校")

    desk = described_class.new(user:).call(lexemes: [word])

    expect(desk.kind).to(eq("manual"))
    expect(desk.user).to(eq(user))
    expect(desk.name).to(eq("Random #1"))
    expect(desk.lexemes).to(include(word))
    expect(LexemeMemory.owned_by(user).where(lexeme_id: word.id)).to(exist)
  end

  it "increments the Random #N name per user" do
    described_class.new(user:).call(lexemes: [])
    second = described_class.new(user:).call(lexemes: [])

    expect(second.name).to(eq("Random #2"))
  end

  it "segments pasted text into known lexemes" do
    create(:lexeme, kind: :word, text: "學校")

    desk = described_class.new(user:).call(text: "我去學校")

    expect(desk.lexemes.map(&:text)).to(include("學校"))
  end
end
