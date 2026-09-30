# frozen_string_literal: true

require "rails_helper"

RSpec.describe StatsReport do
  let(:user) { create(:user) }

  def memory(facet: :recognition, **attributes)
    lexeme = create(:lexeme)
    LexemeMemory.create!(lexeme:, user:, facet:, activated_at: Time.current, **attributes)
  end

  def review(memory, rating: :good, state_before: :review, reviewed_at: Time.current)
    LexemeReview.create!(
      lexeme_memory: memory,
      lexeme: memory.lexeme,
      user:,
      reviewed_at:,
      rating: Fsrs::Scheduler::RATINGS.fetch(rating),
      facet: LexemeMemory.facets[memory.facet],
      state_before: LexemeMemory.states[state_before.to_s]
    )
  end

  def report
    described_class.new(user:)
  end

  it "computes actual retention over review-state reviews only" do
    subject_memory = memory
    review(subject_memory, rating: :good, state_before: :review, reviewed_at: 1.day.ago)
    review(subject_memory, rating: :again, state_before: :review, reviewed_at: 2.days.ago)
    review(subject_memory, rating: :again, state_before: :unseen, reviewed_at: 1.day.ago)

    expect(report.actual_retention).to(eq(0.5))
  end

  it "returns nil retention without review history" do
    expect(report.actual_retention).to(be_nil)
  end

  it "counts reviews by day including empty days" do
    subject_memory = memory
    review(subject_memory, reviewed_at: Time.current)
    review(subject_memory, reviewed_at: Time.current)
    review(subject_memory, reviewed_at: 1.day.ago)

    expect(report.reviews_by_day(days: 3).map(&:last)).to(eq([0, 1, 2]))
  end

  it "ignores another person's reviews" do
    stranger = create(:user)
    subject_memory = memory
    LexemeReview.create!(
      lexeme_memory: subject_memory,
      lexeme: subject_memory.lexeme,
      user: stranger,
      reviewed_at: Time.current,
      rating: Fsrs::Scheduler::RATINGS.fetch(:good),
      facet: LexemeMemory.facets["recognition"],
      state_before: LexemeMemory.states["review"]
    )

    expect(report.reviews_by_day(days: 1).map(&:last)).to(eq([0]))
  end

  it "counts a word as known once any of its skills reached review" do
    lexeme = create(:lexeme)
    LexemeMemory.create!(lexeme:, user:, facet: :recognition, activated_at: Time.current, state: :review)
    LexemeMemory.create!(lexeme:, user:, facet: :tone, activated_at: Time.current, state: :review)
    memory(state: :learning)

    expect(report.words_known).to(eq(1))
  end

  it "reports every skill that has been started, with how much of it is in review" do
    memory(state: :review)
    memory(state: :learning)
    memory(facet: :tone, state: :review)
    memory(facet: :writing)

    expect(report.facet_strength).to(
      eq(
        [
          {facet: "recognition", active: 2, known: 1},
          {facet: "tone", active: 1, known: 1}
        ]
      )
    )
  end

  it "dates a learned word by the review that first sent it a day or more away" do
    travel_to(Time.zone.local(2026, 9, 30, 12)) do
      learned = memory
      LexemeReview.create!(
        lexeme_memory: learned,
        lexeme: learned.lexeme,
        user:,
        reviewed_at: 1.day.ago,
        rating: Fsrs::Scheduler::RATINGS.fetch(:good),
        facet: 0,
        state_before: LexemeMemory.states["learning"],
        scheduled_days: 3.0
      )
      LexemeReview.create!(
        lexeme_memory: learned,
        lexeme: learned.lexeme,
        user:,
        reviewed_at: 10.days.ago,
        rating: Fsrs::Scheduler::RATINGS.fetch(:good),
        facet: 1,
        state_before: LexemeMemory.states["learning"],
        scheduled_days: 2.0
      )
      stepping = memory
      LexemeReview.create!(
        lexeme_memory: stepping,
        lexeme: stepping.lexeme,
        user:,
        reviewed_at: 1.hour.ago,
        rating: Fsrs::Scheduler::RATINGS.fetch(:good),
        facet: 0,
        state_before: LexemeMemory.states["learning"],
        scheduled_days: 0.01
      )

      weeks = report.learned_by_week(weeks: 3)

      expect(weeks.map(&:first)).to(eq([Date.new(2026, 9, 14), Date.new(2026, 9, 21), Date.new(2026, 9, 28)]))
      expect(weeks.map(&:last)).to(eq([1, 0, 0]))
    end
  end

  it "forecasts the week ahead and folds anything overdue into today" do
    travel_to(Time.zone.local(2026, 9, 30, 12)) do
      memory(state: :review, due_at: 3.days.ago)
      memory(state: :review, due_at: 2.hours.from_now)
      memory(state: :review, due_at: 2.days.from_now)
      memory(state: :review, due_at: 30.days.from_now)
      memory(due_at: 1.day.from_now)

      expect(report.forecast(days: 3).map(&:last)).to(eq([2, 0, 1]))
    end
  end

  it "breaks memories down by maturity" do
    memory
    memory(facet: :production, state: :learning)
    memory(state: :review, stability: 30.0)
    memory(state: :review, stability: 5.0)

    expect(report.memory_breakdown).to(eq(unseen: 1, learning: 1, young: 1, mature: 1))
  end

  it "lists a leech lexeme once" do
    lexeme = create(:lexeme)
    LexemeMemory.create!(lexeme:, user:, facet: :recognition, activated_at: Time.current, lapses: 9)
    LexemeMemory.create!(lexeme:, user:, facet: :production, activated_at: Time.current, lapses: 8)

    expect(report.leeches).to(eq([lexeme]))
  end

  it "buckets days by Taipei time, not by UTC" do
    subject_memory = memory
    Time.use_zone("Asia/Taipei") do
      travel_to(Time.zone.local(2025, 4, 15, 0, 30)) do
        review(subject_memory, reviewed_at: Time.zone.local(2025, 4, 15, 0, 10))

        expect(report.reviews_by_day(days: 2).last).to(eq([Date.new(2025, 4, 15), 1]))
      end
    end
  end

  describe "the day streak" do
    it "counts the run that reaches today and remembers the longest one" do
      subject_memory = memory
      [0, 1, 2, 5, 6, 7, 8, 9].each { |offset| review(subject_memory, reviewed_at: offset.days.ago) }

      streak = report.streak

      expect(streak).to(have_attributes(current: 3, longest: 5, days: 8, since: 2.days.ago.to_date))
      expect(streak).to(be_today)
    end

    it "survives until the end of the next day" do
      subject_memory = memory
      [1, 2].each { |offset| review(subject_memory, reviewed_at: offset.days.ago) }

      expect(report.streak).to(have_attributes(current: 2, today?: false))
    end

    it "is over once a whole day was missed" do
      review(memory, reviewed_at: 2.days.ago)

      expect(report.streak).to(have_attributes(current: 0, since: nil, longest: 1, days: 1))
    end

    it "is empty without reviews" do
      expect(report.streak).to(have_attributes(current: 0, longest: 0, days: 0))
    end

    it "counts a day by the learner's own time zone" do
      user.update!(time_zone: "America/Los_Angeles")
      subject_memory = memory

      Time.use_zone(user.zone) do
        travel_to(Time.zone.local(2026, 9, 30, 21, 0)) do
          review(subject_memory, reviewed_at: Time.zone.local(2026, 9, 29, 23, 30))
          review(subject_memory, reviewed_at: Time.zone.local(2026, 9, 30, 20, 0))

          expect(report.streak).to(have_attributes(current: 2, since: Date.new(2026, 9, 29), today?: true))
        end
      end
    end

    it "keeps the days already counted when the learner moves to another time zone" do
      subject_memory = memory
      review(subject_memory, reviewed_at: Time.utc(2026, 9, 27, 17, 0))
      review(subject_memory, reviewed_at: Time.utc(2026, 9, 28, 17, 0))
      user.move_to("Asia/Dubai")

      Time.use_zone(user.zone) do
        travel_to(Time.utc(2026, 9, 30, 18, 0)) do
          review(subject_memory, reviewed_at: Time.current)

          expect(report.streak).to(have_attributes(current: 3, since: Date.new(2026, 9, 28)))
        end
      end
    end
  end

  describe "a move to another time zone" do
    it "does not lose the day that was still running where the learner came from" do
      user.update!(time_zone: "America/Los_Angeles")
      subject_memory = memory
      review(subject_memory, reviewed_at: Time.utc(2026, 9, 28, 15, 0))
      user.move_to("Asia/Taipei")
      landed = review(subject_memory, reviewed_at: Time.utc(2026, 9, 30, 1, 0))
      later = review(subject_memory, reviewed_at: Time.utc(2026, 9, 30, 1, 5))
      now = Time.utc(2026, 9, 30, 1, 5).in_time_zone(user.zone)

      expect([landed, later].map(&:reviewed_on)).to(eq([Date.new(2026, 9, 29), Date.new(2026, 9, 30)]))
      expect(described_class.new(user:, now:).streak.current).to(eq(3))
    end

    it "forgives nothing once the first review after the move is in" do
      user.update!(time_zone: "America/Los_Angeles")
      subject_memory = memory
      user.move_to("Asia/Taipei")
      review(subject_memory, reviewed_at: Time.utc(2026, 9, 28, 15, 0))
      late = review(subject_memory, reviewed_at: Time.utc(2026, 9, 29, 16, 30))

      expect(user.reload.previous_time_zone).to(be_nil)
      expect(late.reviewed_on).to(eq(Date.new(2026, 9, 30)))
    end

    it "does not bridge a day that was missed in both zones" do
      user.update!(time_zone: "America/Los_Angeles")
      subject_memory = memory
      review(subject_memory, reviewed_at: Time.utc(2026, 9, 27, 15, 0))
      user.move_to("Asia/Taipei")
      late = review(subject_memory, reviewed_at: Time.utc(2026, 9, 30, 1, 0))

      expect(late.reviewed_on).to(eq(Date.new(2026, 9, 30)))
    end

    it "remembers Taiwan as the zone a learner comes from when none was known" do
      user.move_to("Pacific/Auckland")

      expect(user).to(have_attributes(time_zone: "Pacific/Auckland", previous_time_zone: "Asia/Taipei"))
    end

    it "asks nothing extra of the database for a learner who stays put" do
      user.update!(time_zone: "America/Los_Angeles")
      subject_memory = memory
      lookups = []
      callback = lambda { |*, payload| lookups << payload[:sql] if payload[:sql].start_with?("SELECT") }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { review(subject_memory) }

      expect(lookups.grep(/lexeme_reviews/)).to(be_empty)
    end
  end

  it "lays the activity out in whole weeks that end today" do
    review(memory, reviewed_at: Time.current)

    activity = report.activity(weeks: 3)

    expect(activity.first.first).to(eq(2.weeks.ago.to_date.beginning_of_week))
    expect(activity.last).to(eq([Date.current, 1]))
  end
end
