# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Triage sweep" do
  let!(:known) { create(:lexeme, kind: :character, text: "水", meanings: {"en" => "water"}) }
  let!(:unsure) { create(:lexeme, kind: :character, text: "火", meanings: {"en" => "fire"}) }

  def memories(lexeme) = LexemeMemory.owned_by(@authenticated_user).where(lexeme:)

  it "offers unsorted characters" do
    get("/triage")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("&quot;id&quot;:#{known.id}"))
  end

  it "pushes what the learner knows far out without losing it" do
    post("/triage", params: {known: [known.id], normal: [unsure.id]}, as: :json)

    expect(response).to(have_http_status(:ok))
    marked = memories(known).first
    expect(marked.state).to(eq("review"))
    expect(marked.due_at).to(be > 20.days.from_now)
    expect(marked.stability).to(be > 40)
  end

  it "leaves the unsure ones in the ordinary queue" do
    post("/triage", params: {known: [known.id], normal: [unsure.id]}, as: :json)

    kept = memories(unsure).first
    expect(kept).to(be_present)
    expect(kept.state).to(eq("unseen"))
  end

  it "spreads the far-out dates instead of stacking them on one day" do
    many = Array.new(80) { |i| create(:lexeme, kind: :character, text: "験#{i}", meanings: {"en" => "x"}) }

    post("/triage", params: {known: many.map(&:id)}, as: :json)

    dates = LexemeMemory.owned_by(@authenticated_user).where(lexeme: many).pluck(:due_at).compact.map(&:to_date).uniq
    expect(dates.size).to(be > 5)
  end

  it "does not disturb something the learner has genuinely been studying" do
    Lexemes::Activator.new.call(known)
    memories(known).update_all(state: LexemeMemory.states[:review], reps: 6, due_at: 2.days.from_now)

    post("/triage", params: {known: [known.id]}, as: :json)

    memory = memories(known).first
    expect(memory.reps).to(eq(6))
    expect(memory.due_at).to(be > 20.days.from_now)
  end

  it "keeps sorted characters out of the next batch" do
    post("/triage", params: {known: [known.id]}, as: :json)

    get("/triage")

    expect(response.body).not_to(include("&quot;id&quot;:#{known.id}"))
    expect(response.body).to(include("&quot;id&quot;:#{unsure.id}"))
  end
end
