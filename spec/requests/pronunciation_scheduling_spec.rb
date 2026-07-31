# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pronunciation scheduling" do
  let!(:word) do
    create(:lexeme, kind: :word, text: "學校", readings: {"pinyin" => "xué xiào"}, meanings: {"en" => "school"})
  end

  let(:result) do
    {"syllables" => [{"level" => "amber", "overall" => 60, "tone" => 2}], "overall" => 60}
  end

  before do
    allow_any_instance_of(Pronunciation::AcousticBackend).to(receive(:grade).and_return(result))
    allow_any_instance_of(Pronunciation::SkillRecorder).to(receive(:call))
  end

  def grade(extra = {})
    post(
      pronunciation_grade_path,
      params: {lexeme_id: word.id, text: "學校", expected: "[]", tonal: "true"}.merge(extra)
    )
  end

  it "writes one review per attempt for the standalone trainer" do
    expect { grade }.to(change(LexemeReview, :count).by(1))
  end

  it "writes no review when the caller schedules the card itself" do
    expect { grade(schedule: "false") }.not_to(change(LexemeReview, :count))
  end

  it "still records the syllable skill when scheduling is left to the caller" do
    expect_any_instance_of(Pronunciation::SkillRecorder).to(receive(:call))

    grade(schedule: "false")

    expect(response).to(have_http_status(:ok))
  end

  it "lets a card retry as often as it likes without touching the schedule" do
    3.times { grade(schedule: "false") }

    expect(LexemeReview.where(lexeme: word)).to(be_empty)
  end
end
