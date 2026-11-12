# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::RejectPurge do
  let(:store) { Huayu::SentenceRejectStore }
  let(:collocations) { Huayu::CollocationRejectStore }
  let(:words) { Huayu::WordRejectStore }
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
    allow(words).to(receive(:path).and_return(scratch.join("word_rejects.jsonl")))
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

  it "removes a word listed under its old spelling and leaves the new headword" do
    doomed = Lexeme.create!(kind: :word, text: "打吃")
    keeper = Lexeme.create!(kind: :word, text: "叫吃")
    listed(doomed.text, "renamed", into: words)

    expect(described_class.new(io: StringIO.new).call[:word]).to(include(listed: 1, found: 1, removed: 1))
    expect(Lexeme.exists?(doomed.id)).to(be(false))
    expect(Lexeme.exists?(keeper.id)).to(be(true))
  end

  it "spares a listed word someone is already studying" do
    studied = Lexeme.create!(kind: :word, text: "鼠標")
    LexemeMemory.create!(lexeme: studied, user: nil, facet: :recognition, activated_at: Time.current)
    listed(studied.text, "off_taiwan", into: words)

    expect(described_class.new(io: StringIO.new).call[:word]).to(include(removed: 0, studied: 1))
    expect(Lexeme.exists?(studied.id)).to(be(true))
  end

  it "removes nothing the second time" do
    Lexeme.create!(kind: :word, text: "酸奶")
    listed("酸奶", "off_taiwan", into: words)
    described_class.new(io: StringIO.new).call

    expect(described_class.new(io: StringIO.new).call[:word]).to(include(listed: 1, found: 0, removed: 0))
  end

  it "rebuilds the segmentation vocabulary once a word is gone" do
    Lexeme.create!(kind: :word, text: "莜麥菜")
    listed("莜麥菜", "off_taiwan", into: words)
    allow(Huayu::TextAnalyzer).to(receive(:reset_vocabulary!))

    described_class.new(io: StringIO.new).call

    expect(Huayu::TextAnalyzer).to(have_received(:reset_vocabulary!))
  end

  it "names the words it would remove and the ones it keeps" do
    Lexeme.create!(kind: :word, text: "定式")
    studied = Lexeme.create!(kind: :word, text: "鼠標")
    LexemeMemory.create!(lexeme: studied, user: nil, facet: :recognition, activated_at: Time.current)
    listed("定式", "renamed", into: words)
    listed("鼠標", "off_taiwan", into: words)
    io = StringIO.new

    described_class.new(io:).call(dry_run: true)

    expect(io.string).to(include("to remove 1\n    定式\n", "studying them: 1\n    鼠標\n"))
  end

  it "acts only on the stores it is given" do
    word = Lexeme.create!(kind: :word, text: "打吃")
    collocation = Lexeme.create!(kind: :collocation, text: "服務員")
    listed(word.text, "renamed", into: words)
    listed(collocation.text, "off_corpus", into: collocations)

    result = described_class.new(io: StringIO.new, stores: [words]).call

    expect(result.keys).to(eq([:word]))
    expect(Lexeme.exists?(word.id)).to(be(false))
    expect(Lexeme.exists?(collocation.id)).to(be(true))
  end
end
