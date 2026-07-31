# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Huayu::SentenceRejectPurge) do
  let(:store) { Huayu::SentenceRejectStore }
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

  before { store.write([]) }

  after { store.path.delete if store.path.exist? }

  def sentence(text)
    lexeme = Lexeme.new(kind: :sentence, text:)
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  def listed(text, reason)
    store.append([store::Entry.new(text:, reason:, note: nil)])
  end

  it "removes a sentence the store lists as unusable" do
    doomed = sentence("常常讓我的心")
    listed(doomed.text, "fragment")

    expect(described_class.new(io: StringIO.new).call).to(include(removed: 1))
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

    result = described_class.new(io: StringIO.new).call
    expect(Lexeme.exists?(doomed.id)).to(be(true))
    expect(result).to(include(removed: 0, studied: 1))
  end

  it "reports without deleting on a dry run" do
    doomed = sentence("這個東西好像")
    listed(doomed.text, "fragment")

    expect(described_class.new(io: StringIO.new).call(dry_run: true)).to(include(found: 1, removed: 0))
    expect(Lexeme.exists?(doomed.id)).to(be(true))
  end

  it "counts entries that are no longer in the corpus" do
    listed("早就不存在的句子", "garbled")

    expect(described_class.new(io: StringIO.new).call).to(include(listed: 1, found: 0, removed: 0))
  end
end
