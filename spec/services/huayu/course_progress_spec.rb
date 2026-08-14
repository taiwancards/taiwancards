# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::CourseProgress do
  let(:user) { create(:user) }

  before { described_class.forget_words! }

  after { described_class.forget_words! }

  def finish(lesson, days_ago:)
    CourseCompletion.create!(
      user:,
      slug: lesson.slug,
      score: 8,
      total: 9,
      completed_at: days_ago.days.ago
    )
  end

  it "reports nothing done for a new user" do
    progress = described_class.new(user)

    expect(progress.overall).to(eq(0))
    expect(progress.slices.map(&:done)).to(all(eq(0)))
    expect(progress.pace).to(be_nil)
  end

  it "counts finished lessons, words and grammar for the stage they belong to" do
    lesson = Huayu::CourseLessons.lessons.first
    finish(lesson, days_ago: 1)

    slice = described_class.new(user).slice_for(lesson.stage)

    expect(slice.done).to(eq(1))
    expect(slice.grammar_met).to(eq(lesson.grammar.size))
    expect(slice.words_met).to(be <= lesson.words.size)
    expect(slice.percent).to(eq((100.0 / slice.lessons).round))
  end

  it "works out a pace and a finishing date once two lessons are done" do
    Huayu::CourseLessons.lessons.first(2).each_with_index { |lesson, index| finish(lesson, days_ago: 7 - index * 7) }

    pace = described_class.new(user).pace

    expect(pace.lessons).to(eq(2))
    expect(pace.days).to(eq(7))
    expect(pace.per_week).to(eq(2.0))
    expect(pace.finish_by(4)).to(eq(Date.current + 14))
  end

  it "keeps each lesson's share of its level in step with the level size" do
    slice = described_class.new(user).slices.first

    expect(slice.lesson_share).to(be_within(0.01).of(100.0 / slice.lessons))
  end
end
