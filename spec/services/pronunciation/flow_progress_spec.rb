# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::SkillRecorder do
  let(:user) { create(:user) }
  let(:word) { create(:lexeme, kind: :word, text: "教堂", readings: {"pinyin" => "jiàotáng"}) }

  def syllable(key, overall: 90)
    {"key" => key, "overall" => overall, "level" => "green", "cells" => {}, "codes" => []}
  end

  def flow(code, score)
    {"score" => score, "code" => code, "junctions" => [{"index" => 0, "score" => score, "code" => code}]}
  end

  it "credits the junction to the syllable that follows it" do
    described_class
      .new(user, word)
      .call([syllable("jiao4"), syllable("tang2")], flow: flow("flow.ok", 88))

    expect(SyllableSkill.find_by(user:, syllable_key: "jiao4").n_flow).to(eq(0))

    second = SyllableSkill.find_by(user:, syllable_key: "tang2")
    expect(second.n_flow).to(eq(1))
    expect(second.ewma_flow).to(eq(88.0))
  end

  it "remembers how the learner keeps breaking the join" do
    3.times do
      described_class
        .new(user, word)
        .call([syllable("jiao4"), syllable("tang2")], flow: flow("flow.choppy", 40))
    end

    skill = SyllableSkill.find_by(user:, syllable_key: "tang2")
    expect(skill.habitual_error).to(eq({"code" => "flow.choppy", "n" => 3}))
    expect(skill.ewma_flow).to(be_within(0.1).of(40.0))
  end

  it "leaves a single syllable with no junction to answer for" do
    described_class.new(user, word).call([syllable("jiao4")])

    expect(SyllableSkill.find_by(user:, syllable_key: "jiao4").n_flow).to(eq(0))
  end
end
