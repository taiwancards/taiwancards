# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profile reset", :no_auth do
  let!(:lexeme) { create(:lexeme, kind: :word, text: "學校") }

  it "wipes only the current user's progress" do
    me = sign_in(create(:user))
    other = create(:user)
    LexemeMemory.create!(lexeme:, facet: :recognition, user: me, activated_at: Time.current)
    LexemeMemory.create!(lexeme:, facet: :recognition, user: other, activated_at: Time.current)
    PronunciationAttempt.create!(user: me, lexeme:, created_at: Time.current)
    SyllableSkill.claim(me, "xue2").record!(overall: 70, level: "amber")

    delete("/profile/reset")

    expect(response).to(redirect_to(profile_path))
    expect(me.lexeme_memories.count).to(eq(0))
    expect(PronunciationAttempt.owned_by(me).count).to(eq(0))
    expect(SyllableSkill.where(user: me).count).to(eq(0))
    expect(other.lexeme_memories.count).to(eq(1))
  end
end
