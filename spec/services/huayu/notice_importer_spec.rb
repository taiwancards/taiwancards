# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::NoticeImporter do
  let!(:source) do
    ContentSource.create!(
      slug: described_class::SOURCE,
      name: "社區公告範本",
      license_commercial: true,
      register: :official,
      enabled: true,
      enabled_for_admins: true,
      attribution: "TaiwanCards."
    )
  end

  def run = described_class.new.call

  it "stores every notice line as a sentence carrying the notices source" do
    result = run

    expect(result.imported).to(eq(Huayu::TaiwanNotices.sentences.size))
    stored = Lexeme.where(kind: :sentence).where("data ->> 'notice' IS NOT NULL")
    expect(stored.count).to(eq(result.imported))
    expect(stored.first.content_sources).to(include(source))
  end

  it "segments each line so its words can be linked" do
    run

    Lexeme.where(kind: :sentence).where("data ->> 'notice' IS NOT NULL").find_each do |sentence|
      expect(sentence.data["segments"]).to(be_present)
      expect(sentence.data["difficulty"]).to(be_present)
    end
  end

  it "keeps both translations on the sentence" do
    run

    sentence = Lexeme.find_by(kind: :sentence, text: Huayu::TaiwanNotices.all.first.items.first.zh)
    expect(sentence.meanings["ru"]).to(be_present)
    expect(sentence.meanings["en"]).to(be_present)
  end

  it "is idempotent and reports drift only while something is missing" do
    expect(described_class.new).to(be_drift)
    run
    expect(described_class.new).not_to(be_drift)

    again = run
    expect(again.imported).to(eq(0))
    expect(again.retired).to(eq(0))
  end

  it "retires a line that the file no longer carries" do
    run
    orphan = Lexeme.new(kind: :sentence, text: "這是一則過期的公告。", data: {"notice" => true})
    orphan.lexeme_content_sources.build(content_source: source)
    orphan.save!

    expect(run.retired).to(eq(1))
    expect(Lexeme.exists?(orphan.id)).to(be(false))
  end
end
