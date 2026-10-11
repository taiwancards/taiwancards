# frozen_string_literal: true

require "rails_helper"

RSpec.describe Study::Upkeep do
  let(:user) { create(:user, prefs: {"level" => "3"}) }
  let(:now) { Time.zone.local(2026, 10, 20, 19) }

  def memory!(text, level:, due_at: now, state: :review)
    lexeme = create(:lexeme, kind: :word, text:, data: {"tbcl_grade" => level, "freq_rank" => 100})
    LexemeMemory.create!(user:, lexeme:, facet: :recognition, state:, due_at:, stability: 40, difficulty: 5, reps: 1)
  end

  def check!(memory, rating:, elapsed_ms: 2_000, at: now - 1.day)
    LexemeReview.create!(
      user:,
      lexeme: memory.lexeme,
      lexeme_memory: memory,
      facet: :recognition,
      rating:,
      elapsed_ms:,
      reviewed_at: at,
      state_before: LexemeMemory.states[:review]
    )
  end

  it "takes a slow right answer on a known word as hard, and leaves new-level words alone" do
    known = memory!("舊", level: 2)
    fresh = memory!("新", level: 4)
    upkeep = described_class.new(user, now:)

    expect(upkeep.rating_for(known, "good", "9000")).to(eq("hard"))
    expect(upkeep.rating_for(known, "good", "2000")).to(eq("good"))
    expect(upkeep.rating_for(known, "good", "600000")).to(eq("good"))
    expect(upkeep.rating_for(fresh, "good", "9000")).to(eq("good"))
  end

  it "brings resting words of the level forward when the checks go badly, once a day" do
    rested = 8.times.map { |i| memory!("休#{i}", level: 3, due_at: now + 400.days) }
    checked = memory!("查", level: 2)
    6.times { check!(checked, rating: 3) }
    4.times { check!(checked, rating: 1) }

    described_class.new(user, now:).refresh

    pulled = rested.map(&:reload).count { |memory| memory.due_at <= now }
    expect(pulled).to(eq(described_class::EXTRA_PER_DAY))

    rested.each { |memory| memory.update!(due_at: now + 400.days) }
    described_class.new(user, now: now + 1.hour).refresh
    expect(rested.map(&:reload).count { |memory| memory.due_at <= now }).to(eq(0))
  end

  it "leaves the schedule alone while the known level holds up" do
    rested = memory!("休", level: 3, due_at: now + 400.days)
    checked = memory!("查", level: 2)
    12.times { check!(checked, rating: 3) }

    described_class.new(user, now:).refresh

    expect(rested.reload.due_at).to(be > now + 300.days)
  end
end
