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

  it "checks only the hardest third of the learner's own level and rests everything else" do
    own = 6.times.map { |i| word("本#{i}", {"tbcl_grade" => 2, "freq_rank" => 100 + i}) }
    below = word("下", {"tbcl_grade" => 1, "freq_rank" => 1})

    described_class.new(user, now:).call(2)

    due = -> (lexeme) { LexemeMemory.owned_by(user).where(lexeme:).pick(:due_at) }
    hardest = own.last(2)
    expect(hardest.map(&due)).to(all(be_between(now + 14.days, now + 100.days)))
    expect((own.first(4) + [below]).map(&due)).to(all(be >= now + 365.days))
  end

  it "gives a lowered level its next words back while keeping real progress" do
    upper = word("上", {"tbcl_grade" => 3, "freq_rank" => 50})
    learned = word("學", {"tbcl_grade" => 3, "freq_rank" => 60})
    described_class.new(user, now:).call(3)
    memory = LexemeMemory.owned_by(user).find_by(lexeme: learned, facet: LexemeMemory.facets[:recognition])
    Lexemes::ReviewProcessor.new.call(memory, rating: "good", now: now + 20.days)

    described_class.new(user, now:).reseat(1)

    expect(LexemeMemory.owned_by(user).where(lexeme: upper)).to(be_empty)
    expect(memory.reload.reps).to(eq(2))
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

  it "seeds a memory that was created but never reviewed" do
    target = word("學校", {"tbcl_grade" => 1, "freq_rank" => 5})
    memory = LexemeMemory.create!(lexeme: target, user:, facet: LexemeMemory.facets["recognition"])

    result = described_class.new(user, now:).call(2)

    expect(memory.reload.state).to(eq("review"))
    expect(memory.reps).to(eq(1))
    expect(result[:seeded]).to(eq(2))
  end

  it "honors a facet override that leaves reading out" do
    target = word("謝謝", {"tbcl_grade" => 1, "freq_rank" => 5, "facets" => %w[recognition]})

    described_class.new(user, now:).call(2)

    expect(LexemeMemory.owned_by(user).where(lexeme: target).map(&:facet)).to(eq(["recognition"]))
  end

  it "keeps another user's memories out of the decision" do
    target = word("學校", {"tbcl_grade" => 1, "freq_rank" => 5})
    described_class.new(create(:user), now:).call(2)

    result = described_class.new(user, now:).call(2)

    expect(result[:seeded]).to(eq(2))
    expect(LexemeMemory.where(lexeme: target).count).to(eq(4))
  end

  it "writes in a constant number of statements however many lexemes qualify" do
    40.times { |i| word("詞#{i}", {"tbcl_grade" => 1, "freq_rank" => i + 1}) }

    seeder = described_class.new(user, now:)

    report = count_queries { seeder.call(2) }

    expect(report).to(issue_at_most(3))
    expect(LexemeMemory.owned_by(user).count).to(eq(80))
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
