# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  subject(:user) { build(:user) }

  describe "list-backed preferences" do
    it "falls back to the first allowed value when unset" do
      expect(user.zhuyin_position).to(eq("right"))
      expect(user.text_direction).to(eq("horizontal"))
      expect(user.visibility_scale).to(eq("chars"))
    end

    it "keeps an allowed value" do
      user.zhuyin_position = "over"

      expect(user.zhuyin_position).to(eq("over"))
      expect(user.prefs["zhuyin_position"]).to(eq("over"))
    end

    it "rejects a value outside the list" do
      user.text_direction = "diagonal"

      expect(user.text_direction).to(eq("horizontal"))
    end

    it "uses the declared default rather than the first entry" do
      user.visibility_tolerance = "nonsense"

      expect(user.visibility_tolerance).to(eq("at0"))
    end

    it "allows nil where the preference is optional" do
      expect(user.start_level).to(be_nil)

      user.start_level = "not-a-level"

      expect(user.start_level).to(be_nil)
    end
  end

  describe "range-backed preferences" do
    it "clamps below the floor" do
      user.visibility_scale = "tocfl"
      user.visibility_level = -5

      expect(user.visibility_level).to(eq(1))
    end

    it "clamps above the ceiling" do
      user.visibility_scale = "tocfl"
      user.visibility_level = 999

      expect(user.visibility_level).to(eq(Huayu::LevelThresholds::MAX_LEVEL))
    end
  end

  describe "#visibility_level" do
    it "reports the character tier while the scale is characters" do
      user.character_tier = Huayu::CharacterTiers::SECONDARY

      expect(user.visibility_scale).to(eq("chars"))
      expect(user.visibility_level).to(eq(Huayu::CharacterTiers::SECONDARY))
    end

    it "reports the stored level once a graded scale is chosen" do
      user.project!(scale: "tbcl", level: 3, tolerance: "half")

      expect(user.visibility_scale).to(eq("tbcl"))
      expect(user.visibility_level).to(eq(3))
      expect(user.visibility_tolerance).to(eq("half"))
    end
  end

  describe "#project!" do
    it "switches back to characters and forgets the graded scale" do
      user.project!(scale: "tocfl", level: 4)
      user.project!(scale: "chars", level: Huayu::CharacterTiers::COMMON)

      expect(user.visibility_scale).to(eq("chars"))
      expect(user.visibility_level).to(eq(Huayu::CharacterTiers::COMMON))
    end

    it "treats an unknown scale as characters" do
      user.project!(scale: "hsk", level: 2)

      expect(user.visibility_scale).to(eq("chars"))
    end
  end

  describe "#mobile_tabs" do
    it "drops blanks and keeps at most four" do
      user.mobile_tabs = ["desk", "", nil, "dict", "search", "stats", "history"]

      expect(user.mobile_tabs).to(eq(%w[desk dict search stats]))
    end
  end

  describe "#character_tier=" do
    it "clamps into the known tiers and pins the scale to characters" do
      user.project!(scale: "tbcl", level: 5)
      user.character_tier = 99

      expect(user.character_tier).to(eq(Huayu::CharacterTiers::RARE))
      expect(user.visibility_scale).to(eq("chars"))
    end
  end

  describe "#level" do
    it "starts at zero" do
      expect(user.level).to(eq("zero"))
    end

    it "follows the chosen starting point until a level is set" do
      user.start_level = "phonetics"

      expect(user.level).to(eq("phonetics"))
    end

    it "prefers an explicit level over the starting point" do
      user.start_level = "phonetics"
      user.level = "3"

      expect(user.level).to(eq("3"))
      expect(user.level_grade).to(eq(3))
    end

    it "refuses a level outside the ladder" do
      user.level = "99"

      expect(user.level).to(eq("zero"))
      expect(user.level_grade).to(eq(0))
    end
  end

  describe "counters kept in prefs" do
    it "accumulates phonetic misses and drops the ones that fall to zero" do
      user.save!
      user.record_phonetic_misses!("zh" => 2, "ch" => 0)
      user.record_phonetic_misses!("zh" => 3)

      expect(user.phonetic_misses).to(eq("zh" => 5))
    end

    it "counts practice runs per kind" do
      user.save!
      user.record_practice_run!(:pinyin)
      user.record_practice_run!(:pinyin)
      user.record_practice_run!("zhuyin")

      expect(user.practice_runs).to(eq("pinyin" => 2, "zhuyin" => 1))
    end

    it "adds and removes path steps without duplicating them" do
      user.save!
      user.mark_path_step!("intro")
      user.mark_path_step!("intro")

      expect(user.path_steps_done).to(eq(["intro"]))

      user.unmark_path_step!("intro")

      expect(user.path_steps_done).to(be_empty)
    end
  end
end
