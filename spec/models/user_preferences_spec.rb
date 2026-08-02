# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  subject(:user) { build(:user) }

  describe "list-backed preferences" do
    it "falls back to the first allowed value when unset" do
      expect(user.zhuyin_position).to(eq("right"))
      expect(user.text_direction).to(eq("horizontal"))
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

    it "allows nil where the preference is optional" do
      expect(user.start_level).to(be_nil)

      user.start_level = "not-a-level"

      expect(user.start_level).to(be_nil)
    end
  end

  describe "#mobile_tabs" do
    it "drops blanks and keeps at most four" do
      user.mobile_tabs = ["desk", "", nil, "dict", "search", "stats", "history"]

      expect(user.mobile_tabs).to(eq(%w[desk dict search stats]))
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
