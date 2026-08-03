# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::GrammarMatcher do
  after { described_class.reset! }

  it "finds lessons whose markers occur in the sentence" do
    lessons = described_class.lessons_for("我是學生。")

    expect(lessons.map(&:slug)).to(include("shi"))
  end

  it "detects the A-not-A pattern" do
    lessons = described_class.lessons_for("你知不知道這件事情？")

    expect(lessons.map(&:slug)).to(include("a-not-a"))
  end

  it "returns nothing for text without matches" do
    expect(described_class.lessons_for("abc")).to(eq([]))
  end
end
