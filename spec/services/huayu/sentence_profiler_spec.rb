# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SentenceProfiler do
  let!(:source) do
    ContentSource.create!(
      slug: "spoken",
      name: "Spoken",
      license_commercial: true,
      register: :colloquial,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Spoken."
    )
  end

  def sentence!(text, difficulty:, segments:)
    lexeme = Lexeme.new(kind: :sentence, text:, data: {"difficulty" => difficulty, "segments" => segments})
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  def run(scope = nil) = described_class.new(io: StringIO.new, scope:).call

  it "profiles a sentence that has none yet" do
    lexeme = sentence!("學生讀書。", difficulty: 240, segments: %w[學生 讀書])

    run

    expect(SentenceProfile.find_by(lexeme_id: lexeme.id).difficulty).to(eq(240))
  end

  it "counts a sentence whose stored profile disagrees with its difficulty as stale" do
    lexeme = sentence!("老師說話。", difficulty: 100, segments: %w[老師 說話])
    run
    expect(described_class.stale).to(be_empty)

    lexeme.update_column(:data, lexeme.data.merge("difficulty" => 700))

    expect(described_class.stale.pluck(:id)).to(eq([lexeme.id]))
  end

  it "refreshes only the scope it is given" do
    stale = sentence!("老師說話。", difficulty: 100, segments: %w[老師 說話])
    other = sentence!("學生讀書。", difficulty: 240, segments: %w[學生 讀書])
    run

    stale.update_column(:data, stale.data.merge("difficulty" => 700))
    other.update_column(:data, other.data.merge("difficulty" => 900))

    run(Lexeme.where(id: stale.id))

    expect(SentenceProfile.find_by(lexeme_id: stale.id).difficulty).to(eq(700))
    expect(SentenceProfile.find_by(lexeme_id: other.id).difficulty).to(eq(240))
  end

  it "never calls an entry without Han text stale" do
    create(:lexeme, kind: :collocation, text: "KPI", data: {})

    expect(described_class.stale).to(be_empty)
  end
end
