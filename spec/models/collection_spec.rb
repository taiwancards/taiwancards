# frozen_string_literal: true

require "rails_helper"

RSpec.describe Collection do
  let(:learner) { create(:user) }
  let(:insider) { create(:user, restricted_content: true) }

  let!(:level) { described_class.create!(kind: :tocfl, name: "Novice 1") }
  let!(:lesson) { described_class.create!(kind: :lesson, name: "Textbook B1L01") }
  let!(:own) { described_class.create!(kind: :manual, name: "Mine", user: learner) }
  let!(:foreign) { described_class.create!(kind: :manual, name: "Theirs", user: create(:user)) }

  describe ".curated" do
    it "holds the ownerless editorial collections and no learner's deck" do
      expect(described_class.curated).to(contain_exactly(level, lesson))
    end
  end

  describe ".studyable_by" do
    it "gives a learner their own decks and the open editorial ones, without the textbook lessons" do
      expect(described_class.studyable_by(learner)).to(contain_exactly(level, own))
    end

    it "adds the textbook lessons for an account cleared for restricted content" do
      expect(described_class.studyable_by(insider)).to(contain_exactly(level, lesson))
    end

    it "gives a guest the open editorial collections alone" do
      expect(described_class.studyable_by(nil)).to(contain_exactly(level))
    end
  end

  describe "the kind of an owned deck" do
    it "refuses anything but a manual deck for a learner" do
      deck = described_class.new(kind: :tocfl, name: "Forged level", user: learner)

      expect(deck).not_to(be_valid)
      expect(deck.errors).to(include(:kind))
    end

    it "leaves the editorial kinds to ownerless collections" do
      expect(described_class.new(kind: :everyday, name: "Everyday")).to(be_valid)
    end
  end
end
