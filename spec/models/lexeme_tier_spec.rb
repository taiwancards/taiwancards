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

    it "shows only 常用 by default" do
      expect(Lexeme.visible_to(user)).to(include(common))
      expect(Lexeme.visible_to(user)).not_to(include(secondary))
    end

    it "opens the second tier when the projection reaches it" do
      user.projection = "chars:#{Huayu::CharacterTiers::SECONDARY}"
      user.save!

      expect(Lexeme.visible_to(user)).to(include(common, secondary))
    end

    it "shows a guest only 常用" do
      expect(Lexeme.visible_to(nil)).not_to(include(secondary))
    end
  end

  describe "the tier a projection asks for" do
    it "clamps a tier above the last chart" do
      user.character_tier = 99

      expect(user.character_tier).to(eq(Huayu::CharacterTiers::RARE))
    end

    it "pins the scale to characters" do
      user.project!(scale: "tbcl", level: 5)
      user.projection = "chars:#{Huayu::CharacterTiers::COMMON}"

      expect(user.visibility_scale).to(eq("chars"))
      expect(user.visibility_level).to(eq(Huayu::CharacterTiers::COMMON))
    end
  end
end
