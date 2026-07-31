# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::RejectPurge do
  let(:store) { Huayu::SentenceRejectStore }
  let(:collocations) { Huayu::CollocationRejectStore }
  let!(:source) do
    ContentSource.create!(
      slug: "spoken",
      name: "Spoken",
      license_commercial: true,
      register: :colloquial,
      enabled: true,
      attribution: "Spoken."
    )
  end

  let(:scratch) { Pathname(Dir.mktmpdir) }

  before do
    allow(store).to(receive(:path).and_return(scratch.join("sentence_rejects.jsonl")))
    allow(collocations).to(receive(:path).and_return(scratch.join("collocation_rejects.jsonl")))
  end

  after { scratch.rmtree }

  def sentence(text)
    lexeme = Lexeme.new(kind: :sentence, text:)
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  def listed(text, reason, into: store)
    into.append([into::Entry.new(text:, reason:, note: nil)])
  end

  it "removes a sentence the store lists as unusable" do
    doomed = sentence("常常讓我的心")
    listed(doomed.text, "fragment")

    expect(described_class.new(io: StringIO.new).call[:sentence]).to(include(removed: 1))
    expect(Lexeme.exists?(doomed.id)).to(be(false))
  end

  it "leaves sentences the store says nothing about" do
    keeper = sentence("我是一個媽媽")
    listed("常常讓我的心", "fragment")

    described_class.new(io: StringIO.new).call
    expect(Lexeme.exists?(keeper.id)).to(be(true))
  end

  it "spares a sentence someone is already studying" do
    doomed = sentence("會走路的錢")
    LexemeMemory.create!(lexeme: doomed, user: nil, facet: :recognition, activated_at: Time.current)
    listed(doomed.text, "ambiguous")

    result = described_class.new(io: StringIO.new).call[:sentence]
    expect(Lexeme.exists?(doomed.id)).to(be(true))
    expect(result).to(include(removed: 0, studied: 1))
  end

  it "reports without deleting on a dry run" do
    doomed = sentence("這個東西好像")
    listed(doomed.text, "fragment")

    expect(described_class.new(io: StringIO.new).call(dry_run: true)[:sentence]).to(include(found: 1, removed: 0))
    expect(Lexeme.exists?(doomed.id)).to(be(true))
  end

  it "counts entries that are no longer in the corpus" do
    listed("早就不存在的句子", "garbled")

    expect(described_class.new(io: StringIO.new).call[:sentence]).to(include(listed: 1, found: 0, removed: 0))
  end

  it "removes a collocation listed as not Taiwanese usage" do
    doomed = Lexeme.create!(kind: :collocation, text: "服務員")
    keeper = Lexeme.create!(kind: :collocation, text: "服務生")
    listed(doomed.text, "off_corpus", into: collocations)

    expect(described_class.new(io: StringIO.new).call[:collocation]).to(include(removed: 1))
    expect(Lexeme.exists?(doomed.id)).to(be(false))
    expect(Lexeme.exists?(keeper.id)).to(be(true))
  end

  it "keeps the two stores apart" do
    text = "服務員"
    same = sentence(text)
    listed(text, "off_corpus", into: collocations)

    described_class.new(io: StringIO.new).call
    expect(Lexeme.exists?(same.id)).to(be(true))
  end
end
