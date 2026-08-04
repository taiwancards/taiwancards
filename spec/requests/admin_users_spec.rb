# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin users" do
  it "redirects a non-admin away from the admin area" do
    get(admin_users_path)
    expect(response).to(redirect_to(root_path))
  end

  it "lets an admin list users and toggle a target's languages and restricted access" do
    sign_in(create(:user, :admin))
    target = create(:user)

    get(admin_users_path)
    expect(response).to(have_http_status(:ok))

    patch(admin_user_path(target), params: {user: {restricted_content: "1"}})
    expect(response).to(redirect_to(admin_users_path))

    target.reload
    expect(target.restricted_content?).to(be(true))
  end

  describe "admin rights" do
    let(:admin) { create(:user, :admin) }

    before { sign_in(admin) }

    it "is no longer something a form can hand out" do
      other = create(:user)

      patch(admin_user_path(other), params: {user: {restricted_content: "1"}})

      expect(other.reload).not_to(be_admin)
      expect(other.restricted_content?).to(be(true))
    end

    it "cannot be granted in code either, only by signing in with that Google account" do
      other = create(:user)

      other.update!(admin: true)

      expect(other.reload.admin).to(be(false))
      expect(other).not_to(be_admin)
    end

    it "cannot be taken away from that account" do
      admin.update!(admin: false)

      expect(admin.reload.admin).to(be(true))
      expect(admin).to(be_admin)
    end

    it "lets an admin change their own unrelated settings" do
      patch(admin_user_path(admin), params: {user: {restricted_content: "1"}})

      expect(admin.reload.restricted_content?).to(be(true))
      expect(admin).to(be_admin)
    end
  end

  describe "deleting a user" do
    let(:admin) { create(:user, :admin) }

    before { sign_in(admin) }

    def user_with_everything
      victim = create(:user, email: "victim@example.com")
      lexeme = create(:lexeme, kind: :word, text: "資料")

      memory = LexemeMemory.create!(
        lexeme:,
        user: victim,
        facet: LexemeMemory.facets["recognition"],
        state: :review,
        stability: 10.0,
        difficulty: 5.0,
        activated_at: Time.current,
        due_at: 1.day.from_now
      )
      LexemeReview.create!(
        lexeme_memory: memory,
        lexeme:,
        user: victim,
        facet: LexemeMemory.facets["recognition"],
        rating: 3,
        reviewed_at: Time.current
      )
      desk = Collection.create!(kind: :manual, name: "Victim desk", user: victim)
      desk.add_lexeme(lexeme)
      ReadingText.create!(user: victim, collection: desk, kind: :article, title: "T", body: "資料")
      PlacementTest.create!(user: victim, status: :finished, result_grade: 2)
      StudyPlan.create!(user: victim, target_level: "A1", target_date: 30.days.from_now)
      PronunciationAttempt.create!(lexeme:, user: victim, ok: true, recognized: "資料")

      victim
    end

    it "erases the user and every record attached to them" do
      victim = user_with_everything

      delete(admin_user_path(victim))

      expect(User.find_by(id: victim.id)).to(be_nil)
      expect(LexemeMemory.where(user_id: victim.id)).to(be_empty)
      expect(LexemeReview.where(user_id: victim.id)).to(be_empty)
      expect(Collection.where(user_id: victim.id)).to(be_empty)
      expect(ReadingText.where(user_id: victim.id)).to(be_empty)
      expect(PlacementTest.where(user_id: victim.id)).to(be_empty)
      expect(StudyPlan.where(user_id: victim.id)).to(be_empty)
      expect(PronunciationAttempt.where(user_id: victim.id)).to(be_empty)
    end

    it "leaves the shared dictionary untouched" do
      victim = user_with_everything
      lexemes = Lexeme.count

      delete(admin_user_path(victim))

      expect(Lexeme.count).to(eq(lexemes))
    end

    it "refuses to delete the signed-in admin" do
      expect { delete(admin_user_path(admin)) }.not_to(change(User, :count))
      expect(flash[:alert]).to(eq(I18n.t("admin.delete_self")))
    end
  end
end
