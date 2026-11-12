# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::TbclReadiness do
  let(:user) { create(:user) }

  def graded(text, grade)
    create(:lexeme, kind: :word, text:, data: {"tbcl_grade" => grade})
  end

  def remember(lexeme, owner:, state:, facet: :recognition, activated_at: 1.day.ago)
    LexemeMemory.create!(lexeme:, user: owner, facet:, state:, activated_at:)
  end

  it "counts every graded entry, the ones in progress and the ones already known" do
    known = graded("學校", 1)
    started = graded("老師", 1)
    graded("學生", 1)
    graded("銀行", 2)
    remember(known, owner: user, state: :review)
    remember(known, owner: user, state: :learning, facet: :production)
    remember(started, owner: user, state: :learning)

    first, second, *rest = described_class.new(user:).levels

    expect(first).to(have_attributes(grade: 1, total: 3, started: 2, known: 1, readiness: 33))
    expect(second).to(have_attributes(grade: 2, total: 1, started: 0, known: 0))
    expect(rest.map(&:total)).to(all(eq(0)))
  end

  it "leaves a memory that was never activated out of the progress" do
    word = graded("學校", 1)
    remember(word, owner: user, state: :unseen, activated_at: nil)

    expect(described_class.new(user:).stat(1)).to(have_attributes(started: 0, known: 0))
  end

  it "keeps one learner's progress out of another learner's numbers" do
    word = graded("學校", 1)
    remember(word, owner: create(:user), state: :review)

    expect(described_class.new(user:).stat(1)).to(have_attributes(total: 1, started: 0, known: 0))
  end

  it "skips entries that carry no grade" do
    create(:lexeme, kind: :word, text: "便當")

    expect(described_class.new(user:).levels.sum(&:total)).to(eq(0))
  end

  it "answers a guest from the totals alone" do
    graded("學校", 1)

    report = count_queries { expect(described_class.new(user: nil).stat(1).total).to(eq(1)) }

    expect(report.to_s).not_to(include("lexeme_memories"))
  end

  it "counts the totals once and serves the next reader from the cache" do
    graded("學校", 1)
    described_class.new(user: nil).levels

    report = count_queries { described_class.new(user: nil).levels }

    expect(report.to_s).not_to(include("GROUP BY"))
  end
end
