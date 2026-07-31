# frozen_string_literal: true

require "rails_helper"

RSpec.describe Study::DailyLoad do
  let(:user) { create(:user) }
  let(:lexemes) { Array.new(6) { |index| create(:lexeme, kind: :word, text: "額度#{index}") } }

  def review(lexeme, at:, state_before: LexemeMemory.states[:unseen])
    memory = LexemeMemory.create!(lexeme:, user:, facet: :recognition, activated_at: at)
    LexemeReview.create!(
      lexeme_memory: memory,
      lexeme:,
      user:,
      facet: :recognition,
      rating: 3,
      reviewed_at: at,
      state_before:
    )
  end

  before { user.write_prefs("study" => {"session_size" => 2}) and user.save! }

  it "counts only the new cards seen today" do
    review(lexemes[0], at: Time.current)
    review(lexemes[1], at: Time.current, state_before: LexemeMemory.states[:review])
    review(lexemes[2], at: 2.days.ago)

    load = described_class.new(user)

    expect(load.new_today).to(eq(1))
    expect(load.reviews_today).to(eq(2))
  end

  it "reports the quota as reached once the sitting size is met" do
    2.times { |index| review(lexemes[index], at: Time.current) }

    load = described_class.new(user)

    expect(load.quota).to(eq(2))
    expect(load).to(be_reached)
    expect(load.multiple).to(eq(1))
    expect(load).not_to(be_overreaching)
  end

  it "warns once the day runs to twice the sitting size" do
    4.times { |index| review(lexemes[index], at: Time.current) }

    load = described_class.new(user)

    expect(load.multiple).to(eq(2))
    expect(load).to(be_overreaching)
  end

  it "stays quiet below the quota" do
    review(lexemes[0], at: Time.current)

    load = described_class.new(user)

    expect(load).not_to(be_reached)
    expect(load.remaining_in_quota).to(eq(1))
  end

  it "follows the person's own sitting size, not the installation default" do
    other = create(:user)
    other.write_prefs("study" => {"session_size" => 40})
    other.save!

    expect(described_class.new(other).quota).to(eq(40))
    expect(described_class.new(user).quota).to(eq(2))
  end
end
