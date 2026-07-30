# frozen_string_literal: true

require "rails_helper"

RSpec.describe Placement::Seeder do
  let(:user) { create(:user) }
  let(:now) { Time.zone.parse("2026-06-11 12:00:00") }

  def word(text, data)
    create(:lexeme, kind: :word, text:, meanings: {"en" => "m-#{text}"}, data:)
  end

  it "seeds recognition and reading as review memories, leaving other facets untouched" do
    target = word("學校", {"tocfl_level" => "Novice1", "freq_rank" => 10})

    result = described_class.new(user, now:).call(2)

    memories = LexemeMemory.owned_by(user).where(lexeme: target)
    expect(memories.map(&:facet)).to(contain_exactly("recognition", "reading"))
    expect(memories.map(&:state).uniq).to(eq(["review"]))
    expect(result[:seeded]).to(eq(2))
  end

  it "spreads due dates into the future instead of piling them on day one" do
    5.times { |i| word("詞#{i}", {"tbcl_grade" => 1, "freq_rank" => i + 1}) }

    described_class.new(user, now:).call(2)

    dues = LexemeMemory.owned_by(user).pluck(:due_at)
    expect(dues.min).to(be >= now + 14.days)
    expect(dues.max).to(be <= now + 300.days)
  end

  it "never touches a lexeme that is already being studied" do
    target = word("學校", {"tbcl_grade" => 1, "freq_rank" => 5})
    memory = LexemeMemory.create!(
      lexeme: target,
      user:,
      facet: LexemeMemory.facets["recognition"],
      state: :learning,
      reps: 3,
      stability: 2.0,
      difficulty: 6.0,
      activated_at: now,
      due_at: now
    )

    described_class.new(user, now:).call(2)

    expect(memory.reload.state).to(eq("learning"))
    expect(memory.reps).to(eq(3))
    expect(memory.stability).to(eq(2.0))
  end

  it "is idempotent — a second run seeds nothing new" do
    word("學校", {"tbcl_grade" => 1, "freq_rank" => 5})
    described_class.new(user, now:).call(2)

    second = described_class.new(user, now:).call(2)

    expect(second[:seeded]).to(eq(0))
  end

  it "leaves lexemes above the threshold alone" do
    word("艱澀", {"tocfl_level" => "C", "freq_rank" => 90_000})

    result = described_class.new(user, now:).call(1)

    expect(result[:lexemes]).to(eq(0))
    expect(LexemeMemory.owned_by(user).count).to(eq(0))
  end

  it "skips restricted lexemes" do
    create(
      :lexeme,
      kind: :word,
      text: "受限",
      meanings: {"en" => "restricted"},
      data: {"tbcl_grade" => 1},
      restricted: true
    )

    result = described_class.new(user, now:).call(2)

    expect(result[:lexemes]).to(eq(0))
  end
end
