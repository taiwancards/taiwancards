# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Character tiers" do
  let(:common) { create(:lexeme, kind: :word, text: "水果") }
  let(:secondary) { create(:lexeme, kind: :word, text: "淼淼") }
  let(:user) { create(:user) }

  describe "tier assignment" do
    it "assigns 常用 to an everyday word" do
      expect(common.reload.tier).to(eq(Huayu::CharacterTiers::COMMON))
    end

    it "raises a word to the tier of its rarest character" do
      expect(secondary.reload.tier).to(eq(Huayu::CharacterTiers::SECONDARY))
    end

    it "leaves Kangxi radicals alone" do
      radical = create(:lexeme, kind: :radical, text: "亠")
      expect(radical.reload.tier).to(eq(Huayu::CharacterTiers::COMMON))
    end
  end

  describe "visibility" do
    before do
      common
      secondary
    end

    it "never hides a tier from a signed-in user" do
      expect(Lexeme.visible_to(user)).to(include(common, secondary))
    end

    it "never hides a tier from a guest" do
      expect(Lexeme.visible_to(nil)).to(include(common, secondary))
    end
  end
end
