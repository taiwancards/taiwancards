# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fsrs::Scheduler do
  let(:start_time) { Time.utc(2022, 11, 29, 12, 30, 0) }

  def blank_memory
    {state: :unseen, step: 0, stability: nil, difficulty: nil, last_reviewed_at: nil}
  end

  def apply(scheduler, memory, rating, now)
    result = scheduler.review(**memory, rating:, now:)
    [
      {
        state: result.state,
        step: result.step,
        stability: result.stability,
        difficulty: result.difficulty,
        last_reviewed_at: now
      },
      result
    ]
  end

  it "reproduces the py-fsrs golden interval history" do
    scheduler = described_class.new(parameters: Fsrs::Parameters.default(enable_fuzzing: false))
    ratings = %i[good good good good good good again again good good good good good]
    memory = blank_memory
    now = start_time
    intervals = []

    ratings.each do |rating|
      memory, result = apply(scheduler, memory, rating, now)
      interval_days = ((result.due_at - now) / 86_400).to_i
      intervals << interval_days
      now = result.due_at
    end

    expect(intervals).to(eq([0, 2, 11, 46, 163, 498, 0, 0, 2, 4, 7, 12, 21]))
  end

  it "reproduces the py-fsrs golden memory state" do
    scheduler = described_class.new(parameters: Fsrs::Parameters.default(enable_fuzzing: false))
    ratings = %i[again good good good good good]
    offsets = [0, 0, 1, 3, 8, 21]
    memory = blank_memory
    now = start_time
    result = nil

    ratings.each_with_index do |rating, index|
      now += offsets[index] * 86_400
      memory, result = apply(scheduler, memory, rating, now)
    end

    expect(result.stability).to(be_within(1e-4).of(53.62691))
    expect(result.difficulty).to(be_within(1e-4).of(6.3574867))
  end

  it "clamps difficulty at 1.0 after repeated same-day easy reviews" do
    scheduler = described_class.new(parameters: Fsrs::Parameters.default(enable_fuzzing: false))
    memory = blank_memory
    result = nil

    10.times do |i|
      now = start_time + i / 1_000_000.0
      memory, result = apply(scheduler, memory, :easy, now)
    end

    expect(result.difficulty).to(eq(1.0))
  end

  it "moves a review card into relearning on again" do
    scheduler = described_class.new(parameters: Fsrs::Parameters.default(enable_fuzzing: false))
    result = scheduler.review(
      state: :review,
      step: 0,
      stability: 20.0,
      difficulty: 5.0,
      last_reviewed_at: start_time - 20 * 86_400,
      rating: :again,
      now: start_time
    )

    expect(result.state).to(eq(:relearning))
    expect(result.due_at).to(eq(start_time + 10 * 60))
  end

  it "keeps fuzzed intervals within the documented range" do
    scheduler = described_class.new(
      parameters: Fsrs::Parameters.default(enable_fuzzing: true),
      rng: Random.new(42)
    )
    result = scheduler.review(
      state: :review,
      step: 0,
      stability: 30.0,
      difficulty: 5.0,
      last_reviewed_at: start_time - 30 * 86_400,
      rating: :good,
      now: start_time
    )

    unfuzzed = described_class.new(parameters: Fsrs::Parameters.default(enable_fuzzing: false)).review(
      state: :review,
      step: 0,
      stability: 30.0,
      difficulty: 5.0,
      last_reviewed_at: start_time - 30 * 86_400,
      rating: :good,
      now: start_time
    )
    base_days = unfuzzed.interval_days
    delta = 1.0 + (0.15 * 4.5) + (0.1 * 13.0) + (0.05 * (base_days - 20.0))

    expect(result.interval_days).to(be_between((base_days - delta - 1).floor, (base_days + delta + 1).ceil))
  end

  it "computes retrievability as a power curve" do
    scheduler = described_class.new(parameters: Fsrs::Parameters.default(enable_fuzzing: false))
    expect(scheduler.retrievability(0, 10.0)).to(eq(1.0))
    expect(scheduler.retrievability(10, 10.0)).to(be_within(1e-9).of(0.9))
  end
end
