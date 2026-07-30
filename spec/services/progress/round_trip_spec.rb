# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Progress export and restore", :aggregate_failures do
  let(:user) { create(:user, name: "Old", locale: "ru") }
  let!(:word) { create(:lexeme, kind: :word, text: "學校", readings: {"pinyin" => "xuéxiào"}) }
  let!(:character) { create(:lexeme, kind: :character, text: "水") }

  def populate!
    user.update!(prefs: user.prefs.merge("level" => "b1", "mobile_tabs" => %w[desk study]))

    memory = LexemeMemory.create!(
      user:,
      lexeme: word,
      facet: :recognition,
      activated_at: 3.days.ago,
      state: "review",
      stability: 12.5,
      difficulty: 5.1,
      reps: 4,
      lapses: 1,
      step: 2,
      due_at: 2.days.from_now
    )
    LexemeReview.create!(
      lexeme_memory: memory,
      lexeme: word,
      user:,
      facet: :recognition,
      rating: 3,
      reviewed_at: 2.days.ago,
      elapsed_ms: 1800,
      state_before: "learning"
    )

    SyllableSkill.claim(user, "xue2").record!(
      overall: 71,
      level: "amber",
      parts: {"initial" => 64, "final" => 80, "tone" => 70},
      deviations: {"vot_ms" => -1.4},
      codes: ["initial.under_aspirated"],
      heard: "xue3"
    )

    PronunciationAttempt.create!(
      user:,
      lexeme: word,
      syllable_key: "xue2",
      syllable_index: 0,
      ok: false,
      level: "amber",
      score_overall: 71,
      score_tone: 70,
      best_match: "xue3",
      created_at: 1.day.ago
    )

    VoiceProfile.create!(
      user:,
      f3_ref: 2880.0,
      f1_ref: 500.0,
      f2_ref: 1520.0,
      calibrated_at: 1.day.ago,
      calibration_locale: "ru",
      n_calibration_frames: 420,
      f0_hist: Array.new(VoiceProfile::BINS) { |i| i == 12 ? 400 : 0 }
    )

    deck = Collection.create!(user:, name: "Мои слова", kind: :manual, position: 1)
    CollectionItem.create!(collection: deck, lexeme: word, position: 0)
    CollectionItem.create!(collection: deck, lexeme: character, position: 1)

    ReadingText.create!(user:, title: "Заметка", body: "我今天去學校。", kind: :article)
    StudyPlan.create!(user:, target_level: "B1", target_date: Date.current + 90)
    PlacementTest.create!(user:, status: "finished", result_grade: 4, asked: [1, 2], pending: [])
  end

  def export_then_wipe
    payload = JSON.parse(JSON.generate(Progress::Export.new(user).call))
    user.destroy!
    payload
  end

  it "restores every section into a brand-new account" do
    populate!
    payload = export_then_wipe

    fresh = create(:user, name: "New", locale: "en")
    counts = Progress::Import.new(fresh).call(payload)

    expect(counts).to(include(memories: 1, reviews: 1, syllables: 1, attempts: 1, collections: 1))
    expect(LexemeMemory.owned_by(fresh).count).to(eq(1))
    expect(SyllableSkill.where(user: fresh).count).to(eq(1))
    expect(Collection.where(user: fresh).first.collection_items.count).to(eq(2))
    expect(ReadingText.where(user: fresh).first.body).to(eq("我今天去學校。"))
    expect(StudyPlan.where(user: fresh).first.target_level).to(eq("B1"))
    expect(PlacementTest.where(user: fresh).first.result_grade).to(eq(4))
  end

  it "restores the scheduling state exactly, not just the fact of a card" do
    populate!
    payload = export_then_wipe
    fresh = create(:user)

    Progress::Import.new(fresh).call(payload)

    memory = LexemeMemory.owned_by(fresh).first
    expect(memory).to(have_attributes(state: "review", reps: 4, lapses: 1, step: 2))
    expect(memory.stability).to(be_within(0.01).of(12.5))
    expect(memory.difficulty).to(be_within(0.01).of(5.1))
  end

  it "restores the pronunciation accumulators including the signed bias" do
    populate!
    payload = export_then_wipe
    fresh = create(:user)

    Progress::Import.new(fresh).call(payload)

    skill = SyllableSkill.find_by(user: fresh, syllable_key: "xue2")
    expect(skill).to(have_attributes(n: 1, syllable: "xue", tone: 2))
    expect(skill.mean_z("vot_ms")).to(be_within(0.01).of(-1.4))
    expect(skill.habitual_error).to(be_nil)
    expect(skill.tone_confusions).to(eq({3 => 1}))
  end

  it "restores the voice calibration so tone keeps its absolute reference" do
    populate!
    payload = export_then_wipe
    fresh = create(:user)

    Progress::Import.new(fresh).call(payload)

    profile = VoiceProfile.find_by(user: fresh)
    expect(profile).to(be_calibrated)
    expect(profile.f3_ref).to(be_within(0.1).of(2880.0))
    expect(profile.f0_median).to(be_present)
  end

  it "restores settings without touching credentials" do
    populate!
    payload = export_then_wipe

    expect(payload.to_s).not_to(match(/refresh_token|password_digest/))

    fresh = create(:user)
    Progress::Import.new(fresh).call(payload)

    expect(fresh.reload.prefs).to(include("level" => "b1", "mobile_tabs" => %w[desk study]))
  end

  it "is idempotent" do
    populate!
    payload = export_then_wipe
    fresh = create(:user)

    Progress::Import.new(fresh).call(payload)
    Progress::Import.new(fresh).call(payload)

    expect(LexemeReview.owned_by(fresh).count).to(eq(1))
    expect(PronunciationAttempt.owned_by(fresh).count).to(eq(1))
    expect(Collection.where(user: fresh).count).to(eq(1))
    expect(Collection.where(user: fresh).first.collection_items.count).to(eq(2))
    expect(SyllableSkill.where(user: fresh).sum(:n)).to(eq(1))
  end

  it "skips rows whose entity is missing here instead of failing the whole file" do
    populate!
    payload = export_then_wipe
    word.destroy!

    counts = Progress::Import.new(create(:user)).call(payload)

    expect(counts[:skipped]).to(be_positive)
    expect(counts[:study_plans]).to(eq(1))
  end

  it "still reads a version 1 file" do
    memory = LexemeMemory.create!(user:, lexeme: word, facet: :recognition, activated_at: 1.day.ago, state: "learning")
    legacy = {
      "version" => 1,
      "memories" => [
        {
          "language" => "zh-TW",
          "kind" => "word",
          "text" => "學校",
          "facet" => "recognition",
          "state" => "review",
          "reps" => 2
        }
      ],
      "reviews" => []
    }
    memory.destroy!

    counts = Progress::Import.new(create(:user)).call(legacy)

    expect(counts[:memories]).to(eq(1))
  end
end
