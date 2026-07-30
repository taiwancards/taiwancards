# frozen_string_literal: true

module Progress
  class Summary
    def initialize(user)
      @user = user
    end

    def rows
      [
        {key: "memories", count: LexemeMemory.owned_by(@user).count},
        {key: "reviews", count: LexemeReview.owned_by(@user).count},
        {key: "syllables", count: SyllableSkill.where(user: @user).count},
        {key: "attempts", count: PronunciationAttempt.owned_by(@user).count},
        {key: "collections", count: Collection.where(user: @user).count},
        {key: "reading_texts", count: ReadingText.where(user: @user).count},
        {key: "study_plans", count: StudyPlan.where(user: @user).count},
        {key: "placement_tests", count: PlacementTest.where(user: @user).count}
      ]
    end

    def voice
      @voice ||= VoiceProfile.find_by(user: @user)
    end

    def voice_summary
      voice&.summary
    end

    def pronunciation
      @pronunciation ||= Pronunciation::Focus.new(@user).summary
    end

    def first_seen
      [LexemeReview.owned_by(@user).minimum(:reviewed_at), @user.created_at].compact.min
    end
  end
end
