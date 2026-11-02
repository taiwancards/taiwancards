# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::AuthoredSentenceImporter do
  let(:source) do
    ContentSource.create!(
      slug: described_class::SOURCE,
      name: "例句範本",
      license_commercial: true,
      register: :colloquial,
      enabled: true,
      enabled_for_admins: true,
      attribution: "TaiwanCards."
    )
  end

  let(:rows) { JSON.parse(File.read(described_class::PATH)) }

  def run = described_class.new.call

  def stored = Lexeme.where(kind: :sentence).where("data ->> 'authored' IS NOT NULL")

  it "stores every written sentence with the authored source and all three translations" do
    source
    expect(run.imported).to(eq(rows.size))
    expect(stored.count).to(eq(rows.size))

    sentence = stored.find_by!(text: rows.first["zh"])
    expect(sentence.content_sources).to(include(source))
    expect(sentence.meanings.keys).to(match_array(Locales::ALL))
  end

  it "segments and grades each sentence so its words can be linked" do
    source
    run

    stored.find_each do |sentence|
      expect(sentence.data["segments"]).to(be_present)
      expect(sentence.data["difficulty"]).to(be_present)
    end
  end

  it "keeps translations whole in every language" do
    rows.each do |row|
      expect(row.values_at("zh", *Locales::ALL)).to(all(be_present))
      expect(row.values_at(*Locales::ALL).join).not_to(match(/\p{Han}/))
    end
  end

  it "is idempotent and retires a sentence the file dropped" do
    source
    run
    orphan = Lexeme.new(kind: :sentence, text: "這是一個舊例句。", data: {"authored" => true})
    orphan.lexeme_content_sources.build(content_source: source)
    orphan.save!

    again = run
    expect(again.imported).to(eq(0))
    expect(again.retired).to(eq(1))
  end

  it "does nothing while the source is not registered" do
    expect(described_class.new.call.imported).to(eq(0))
    expect(stored).to(be_empty)
  end
end
