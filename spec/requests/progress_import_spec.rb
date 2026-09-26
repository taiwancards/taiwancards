# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Progress import" do
  let!(:lexeme) { create(:lexeme, kind: :word, text: "學校") }

  def upload(content)
    Rack::Test::UploadedFile.new(StringIO.new(content), "application/json", original_filename: "progress.json")
  end

  it "restores an exported file after the progress was wiped" do
    memory = Lexemes::Activator.new(user: current_user).activate(lexeme, :recognition)
    Lexemes::ReviewProcessor.new.call(memory, rating: "good")
    stability = memory.reload.stability
    get("/profile/export.json")
    exported = response.body
    delete("/profile/reset")
    expect(current_user.lexeme_memories.count).to(eq(0))

    post("/profile/import", params: {file: upload(exported)})

    expect(response).to(redirect_to(profile_path))
    expect(flash[:notice]).to(eq(I18n.t("auth.import_done", memories: 1, reviews: 1, skipped: 0)))
    restored = current_user.lexeme_memories.find_by(lexeme:)
    expect(restored.stability).to(be_within(1e-6).of(stability))
    expect(restored.reps).to(eq(1))
    expect(current_user.lexeme_reviews.count).to(eq(1))
  end

  it "asks for a file when none was chosen" do
    post("/profile/import")

    expect(response).to(redirect_to(profile_path))
    expect(flash[:alert]).to(eq(I18n.t("auth.import_no_file")))
  end

  it "rejects a file that is not a progress export" do
    post("/profile/import", params: {file: upload("not json")})

    expect(response).to(redirect_to(profile_path))
    expect(flash[:alert]).to(eq(I18n.t("auth.import_bad")))
    expect(current_user.lexeme_memories.count).to(eq(0))
  end
end
