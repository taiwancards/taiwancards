# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  def history_for(user, words:)
    lexemes = Array.new(words) { create(:lexeme, :character) }
    lexemes.each do |lexeme|
      memory = LexemeMemory.create!(user:, lexeme:, facet: :recognition, activated_at: Time.current)
      2.times do |turn|
        LexemeReview.create!(
          user:,
          lexeme:,
          lexeme_memory: memory,
          facet: 0,
          rating: 3,
          reviewed_at: turn.days.ago
        )
      end

      PronunciationAttempt.create!(user:, lexeme:, syllable_key: "ma1")
      ActivityEvent.create!(
        user:,
        controller: "study",
        action: "show",
        verb: "GET",
        path: "/study",
        created_at: Time.current
      )
    end
  end

  def deletes_while_destroying(user)
    count_queries { user.destroy! }.statements.grep(/\A\s*DELETE/i)
  end

  it "removes every memory, review, attempt and event of a deleted account" do
    user = create(:user)
    other = create(:user)
    history_for(user, words: 3)
    history_for(other, words: 1)

    user.destroy!

    [LexemeMemory, LexemeReview, PronunciationAttempt, ActivityEvent].each do |model|
      expect(model.where(user_id: user.id)).to(be_empty)
      expect(model.where(user_id: other.id)).to(exist)
    end
  end

  it "deletes the study history in a fixed number of statements however long it is" do
    small = create(:user)
    large = create(:user)
    history_for(small, words: 2)
    history_for(large, words: 12)

    expect(deletes_while_destroying(large).size).to(eq(deletes_while_destroying(small).size))
  end
end
