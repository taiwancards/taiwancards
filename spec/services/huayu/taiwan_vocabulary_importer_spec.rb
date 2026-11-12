# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::TaiwanVocabularyImporter do
  let(:scratch) { Pathname(Dir.mktmpdir) }
  let(:source_file) { scratch.join("taiwan_wiktionary.json") }

  before do
    ContentSource.create!(
      slug: "wiktionary",
      name: "Wiktionary",
      license_commercial: true,
      register: :internet,
      enabled: true,
      attribution: "Wiktionary."
    )
    allow(Huayu::WordRejectStore).to(receive(:path).and_return(scratch.join("word_rejects.jsonl")))
    source_file.write(JSON.generate("鼠標" => {"gloss" => "mouse"}, "機車" => {"gloss" => "scooter"}))
  end

  after { scratch.rmtree }

  it "does not bring back a word the editors rejected" do
    Huayu::WordRejectStore.write([Huayu::WordRejectStore::Entry.new(text: "鼠標", reason: "off_taiwan")])

    described_class.new(path: source_file, io: StringIO.new).call

    expect(Lexeme.exists?(text: "鼠標")).to(be(false))
    expect(Lexeme.exists?(kind: :word, text: "機車")).to(be(true))
  end

  it "leaves a rejected word that is still kept for its learners unmarked" do
    kept = Lexeme.create!(kind: :word, text: "鼠標")
    Huayu::WordRejectStore.write([Huayu::WordRejectStore::Entry.new(text: "鼠標", reason: "off_taiwan")])

    described_class.new(path: source_file, io: StringIO.new).call

    expect(kept.reload.data).not_to(have_key("taiwan_specific"))
  end

  it "imports every word while nothing is rejected" do
    expect(described_class.new(path: source_file, io: StringIO.new).call).to(eq(2))
  end
end
