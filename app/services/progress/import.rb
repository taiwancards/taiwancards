# frozen_string_literal: true

module Progress
  class Import
    SECTIONS = %w[
      settings
      voice
      memories
      reviews
      syllables
      attempts
      collections
      reading_texts
      study_plans
      placement_tests
    ]
      .freeze

    def initialize(user)
      @user = user
      @lexemes = {}
    end

    def call(json)
      @counts = Hash.new(0)

      ActiveRecord::Base.transaction do
        import_settings(json["settings"])
        import_voice(json["voice"])
        Array(json["memories"]).each { |row| import_memory(row) }
        Array(json["reviews"]).each { |row| import_review(row) }
        Array(json["syllables"]).each { |row| import_syllable(row) }
        Array(json["attempts"]).each { |row| import_attempt(row) }
        Array(json["collections"]).each { |row| import_collection(row) }
        Array(json["reading_texts"]).each { |row| import_reading_text(row) }
        Array(json["study_plans"]).each { |row| import_study_plan(row) }
        Array(json["placement_tests"]).each { |row| import_placement_test(row) }
      end

      @counts
    end

    private

    def import_settings(row)
      return if row.blank?
      @user.restricted_content = row["restricted_content"] if row.key?("restricted_content")
      @user.prefs = @user.prefs.merge(row["prefs"] || {})
      @user.save!
      @counts[:settings] += 1
    end

    def import_voice(row)
      return if row.blank?

      profile = VoiceProfile.find_or_initialize_by(user: @user)
      profile.assign_attributes(
        declared_gender: row["declared_gender"],
        calibration_locale: row["calibration_locale"],
        calibrated_at: row["calibrated_at"],
        f0_hist: Array(row["f0_hist"]),
        f0_by_tone: row["f0_by_tone"] || {},
        f1_ref: row["f1_ref"],
        f2_ref: row["f2_ref"],
        f3_ref: row["f3_ref"],
        n_calibration_frames: row["n_calibration_frames"].to_i,
        n_attempts: row["n_attempts"].to_i
      )
      profile.save!
      @counts[:voice] += 1
    end

    def import_memory(row)
      lexeme = find_lexeme(row) or return @counts[:skipped] += 1

      memory = LexemeMemory.find_or_initialize_by(lexeme:, facet: facet_int(row), user: @user)
      memory.assign_attributes(
        state: row["state"].presence || "unseen",
        stability: row["stability"],
        difficulty: row["difficulty"],
        due_at: row["due_at"],
        last_reviewed_at: row["last_reviewed_at"],
        activated_at: row["activated_at"] || memory.activated_at || Time.current,
        reps: row["reps"].to_i,
        lapses: row["lapses"].to_i,
        step: row["step"].to_i
      )
      memory.save!
      @counts[:memories] += 1
    end

    def import_review(row)
      lexeme = find_lexeme(row) or return @counts[:skipped] += 1

      memory = LexemeMemory.find_or_create_by!(lexeme:, facet: facet_int(row), user: @user) do |fresh|
        fresh.activated_at = Time.current
      end

      return if LexemeReview.owned_by(@user).exists?(lexeme:, facet: facet_int(row), reviewed_at: row["reviewed_at"])

      LexemeReview.create!(
        lexeme_memory: memory,
        lexeme:,
        user: @user,
        facet: facet_int(row),
        rating: row["rating"],
        reviewed_at: row["reviewed_at"],
        elapsed_ms: row["elapsed_ms"],
        state_before: row["state_before"],
        stability_after: row["stability_after"],
        difficulty_after: row["difficulty_after"],
        due_after: row["due_after"],
        session_id: row["session_id"]
      )
      @counts[:reviews] += 1
    end

    def import_syllable(row)
      key = row["key"].presence or return @counts[:skipped] += 1

      skill = SyllableSkill.claim(@user, key)
      ewma = row["ewma"] || {}
      skill.assign_attributes(
        n: row["n"].to_i,
        n_green: row["n_green"].to_i,
        n_amber: row["n_amber"].to_i,
        n_red: row["n_red"].to_i,
        n_dark: row["n_dark"].to_i,
        streak: row["streak"].to_i,
        best: row["best"].to_i,
        ewma_overall: ewma["overall"],
        recent: Array(row["recent"]),
        z_sum: Array(row["z_sum"]),
        z_n: Array(row["z_n"]),
        error_counts: Array(row["error_counts"]),
        heard_tones: Array(row["heard_tones"]),
        first_seen_at: row["first_seen_at"],
        last_seen_at: row["last_seen_at"]
      )
      SyllableSkill::PARTS.each { |part| skill.send(:"ewma_#{part}=", ewma[part]) }
      skill.save!
      @counts[:syllables] += 1
    end

    def import_attempt(row)
      lexeme = find_lexeme(row) or return @counts[:skipped] += 1
      if PronunciationAttempt
          .owned_by(@user)
          .exists?(lexeme:, created_at: row["created_at"], syllable_index: row["syllable_index"].to_i)
        return
      end

      scores = row["scores"] || {}
      PronunciationAttempt.create!(
        user: @user,
        lexeme:,
        syllable_key: row["syllable_key"],
        syllable_index: row["syllable_index"].to_i,
        ok: row["ok"].present?,
        level: row["level"],
        rejected: row["rejected"].present?,
        best_match: row["best_match"],
        recognized: row["recognized"],
        score_overall: scores["overall"],
        score_initial: scores["initial"],
        score_medial: scores["medial"],
        score_final: scores["final"],
        score_tone: scores["tone"],
        created_at: row["created_at"]
      )
      @counts[:attempts] += 1
    end

    def import_collection(row)
      name = row["name"].presence or return @counts[:skipped] += 1

      collection = Collection.find_or_initialize_by(user: @user, name:)
      collection.assign_attributes(
        description: row["description"],
        kind: row["kind"].presence || collection.kind,
        level_tag: row["level_tag"],
        position: row["position"].to_i,
        settings: row["settings"] || {},
        last_used_at: row["last_used_at"]
      )
      collection.save!

      Array(row["items"]).each do |item|
        lexeme = find_lexeme(item) or next

        entry = CollectionItem.find_or_initialize_by(collection:, lexeme:)
        entry.position = item["position"].to_i
        entry.save!
      end

      @counts[:collections] += 1
    end

    def import_reading_text(row)
      title = row["title"].presence or return @counts[:skipped] += 1

      text = ReadingText.find_or_initialize_by(user: @user, title:)
      text.assign_attributes(
        body: row["body"],
        author: row["author"],
        kind: row["kind"].presence || text.kind,
        source: row["source"],
        source_url: row["source_url"],
        level_tag: row["level_tag"]
      )
      text.save!
      @counts[:reading_texts] += 1
    end

    def import_study_plan(row)
      plan = StudyPlan.find_or_initialize_by(user: @user)
      plan.assign_attributes(target_level: row["target_level"], target_date: row["target_date"])
      plan.save!
      @counts[:study_plans] += 1
    end

    def import_placement_test(row)
      test = PlacementTest.find_or_initialize_by(user: @user, created_at: row["created_at"])
      test.assign_attributes(
        status: row["status"],
        current_grade: row["current_grade"],
        result_grade: row["result_grade"],
        asked: row["asked"] || [],
        pending: row["pending"] || [],
        seeded_count: row["seeded_count"].to_i
      )
      test.save!
      @counts[:placement_tests] += 1
    end

    def find_lexeme(row)
      kind = Lexeme.kinds[row["kind"]]
      return nil if kind.nil? || row["text"].blank?

      @lexemes.fetch([kind, row["text"]]) do
        @lexemes[[kind, row["text"]]] = Lexeme.find_by(kind:, text: row["text"])
      end
    end

    def facet_int(row)
      LexemeMemory.facets.fetch(row["facet"])
    end
  end
end
