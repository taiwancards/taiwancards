# frozen_string_literal: true

module Progress
  class Export
    VERSION = 2

    def initialize(user)
      @user = user
    end

    def call
      {
        "version" => VERSION,
        "app" => "taiwancards",
        "exported_at" => Time.current.iso8601,
        "user" => profile,
        "settings" => settings,
        "voice" => voice,
        "memories" => memories,
        "reviews" => reviews,
        "syllables" => syllables,
        "attempts" => attempts,
        "collections" => collections,
        "reading_texts" => reading_texts,
        "study_plans" => study_plans,
        "placement_tests" => placement_tests
      }
    end

    private

    def profile
      {
        "email" => @user.email,
        "name" => @user.name,
        "locale" => @user.locale,
        "created_at" => @user.created_at&.iso8601
      }
    end

    def settings
      {
        "restricted_content" => @user.restricted_content,
        "prefs" => @user.prefs
      }
    end

    def voice
      profile = VoiceProfile.find_by(user: @user)
      return nil if profile.nil?

      {
        "declared_gender" => profile.declared_gender,
        "calibration_locale" => profile.calibration_locale,
        "calibrated_at" => profile.calibrated_at&.iso8601,
        "f0_hist" => profile.f0_hist,
        "f0_by_tone" => profile.f0_by_tone,
        "f1_ref" => profile.f1_ref,
        "f2_ref" => profile.f2_ref,
        "f3_ref" => profile.f3_ref,
        "n_calibration_frames" => profile.n_calibration_frames,
        "n_attempts" => profile.n_attempts
      }
    end

    def memories
      LexemeMemory.owned_by(@user).includes(:lexeme).map do |memory|
        key(memory.lexeme).merge(
          "facet" => memory.facet,
          "state" => memory.state,
          "stability" => memory.stability,
          "difficulty" => memory.difficulty,
          "due_at" => memory.due_at&.iso8601,
          "last_reviewed_at" => memory.last_reviewed_at&.iso8601,
          "activated_at" => memory.activated_at&.iso8601,
          "reps" => memory.reps,
          "lapses" => memory.lapses,
          "step" => memory.step
        )
      end
    end

    def reviews
      LexemeReview.owned_by(@user).includes(:lexeme).order(:reviewed_at).map do |review|
        key(review.lexeme).merge(
          "facet" => review.facet,
          "rating" => review.rating,
          "reviewed_at" => review.reviewed_at.iso8601,
          "elapsed_ms" => review.elapsed_ms,
          "state_before" => review.state_before,
          "stability_after" => review.stability_after,
          "difficulty_after" => review.difficulty_after,
          "due_after" => review.due_after&.iso8601,
          "session_id" => review.session_id
        )
      end
    end

    def syllables
      SyllableSkill.where(user: @user).order(:syllable_key).map do |skill|
        {
          "key" => skill.syllable_key,
          "n" => skill.n,
          "n_green" => skill.n_green,
          "n_amber" => skill.n_amber,
          "n_red" => skill.n_red,
          "n_dark" => skill.n_dark,
          "streak" => skill.streak,
          "best" => skill.best,
          "ewma" => SyllableSkill::PARTS
            .index_with { |part| skill.send(:"ewma_#{part}") }
            .merge("overall" => skill.ewma_overall),
          "recent" => skill.recent,
          "z_sum" => skill.z_sum,
          "z_n" => skill.z_n,
          "error_counts" => skill.error_counts,
          "heard_tones" => skill.heard_tones,
          "first_seen_at" => skill.first_seen_at&.iso8601,
          "last_seen_at" => skill.last_seen_at&.iso8601
        }
      end
    end

    def attempts
      PronunciationAttempt.owned_by(@user).includes(:lexeme).order(:created_at).map do |attempt|
        key(attempt.lexeme).merge(
          "syllable_key" => attempt.syllable_key,
          "syllable_index" => attempt.syllable_index,
          "ok" => attempt.ok,
          "level" => attempt.level,
          "rejected" => attempt.rejected,
          "best_match" => attempt.best_match,
          "recognized" => attempt.recognized,
          "scores" => {
            "overall" => attempt.score_overall,
            "initial" => attempt.score_initial,
            "medial" => attempt.score_medial,
            "final" => attempt.score_final,
            "tone" => attempt.score_tone
          }.compact,
          "created_at" => attempt.created_at.iso8601
        )
      end
    end

    def collections
      Collection.where(user: @user).includes(collection_items: :lexeme).map do |collection|
        {
          "name" => collection.name,
          "description" => collection.description,
          "kind" => collection.kind,
          "level_tag" => collection.level_tag,
          "position" => collection.position,
          "settings" => collection.settings,
          "last_used_at" => collection.last_used_at&.iso8601,
          "created_at" => collection.created_at.iso8601,
          "items" => collection.collection_items.filter_map { |item|
            next if item.lexeme.nil?

            key(item.lexeme).merge("position" => item.position)
          }
        }
      end
    end

    def reading_texts
      ReadingText.where(user: @user).map do |text|
        {
          "title" => text.title,
          "body" => text.body,
          "author" => text.author,
          "kind" => text.kind,
          "source" => text.source,
          "source_url" => text.source_url,
          "level_tag" => text.level_tag,
          "created_at" => text.created_at.iso8601
        }
      end
    end

    def study_plans
      StudyPlan.where(user: @user).map do |plan|
        {
          "target_level" => plan.target_level,
          "target_date" => plan.target_date&.iso8601,
          "created_at" => plan.created_at.iso8601
        }
      end
    end

    def placement_tests
      PlacementTest.where(user: @user).map do |test|
        {
          "status" => test.status,
          "current_grade" => test.current_grade,
          "result_grade" => test.result_grade,
          "asked" => test.asked,
          "pending" => test.pending,
          "seeded_count" => test.seeded_count,
          "created_at" => test.created_at.iso8601
        }
      end
    end

    def key(lexeme)
      {"kind" => lexeme.kind, "text" => lexeme.text}
    end
  end
end
