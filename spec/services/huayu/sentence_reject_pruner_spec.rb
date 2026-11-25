# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SentenceRejectPruner do
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

  let(:hidden) do
    ContentSource.create!(
      slug: "hidden",
      name: "Hidden",
      license_commercial: true,
      register: :colloquial,
      enabled: false,
      attribution: "Hidden."
    )
  end

  let(:scratch) { Pathname(Dir.mktmpdir) }
  let(:word) { Lexeme.create!(kind: :word, text: "心") }

  before { allow(store).to(receive(:path).and_return(scratch.join("sentence_rejects.jsonl"))) }

  after { scratch.rmtree }

  def sentence(text = nil, meanings: {}, from: source, of: [])
    @sequence = (@sequence || 0) + 1
    lexeme = Lexeme.new(kind: :sentence, text: text || "第#{@sequence}個例句", meanings:)
    lexeme.lexeme_content_sources.build(content_source: from)
    lexeme.save!
    of.each { |illustrated| SentenceWord.create!(sentence: lexeme, lexeme: illustrated) }
    lexeme
  end

  def examples(count, of: word, meanings: {}, from: source)
    Array.new(count) { sentence(meanings:, from:, of: [of]) }
  end

  def rejected(meanings: {}, of: [word], from: source, reason: "fragment")
    sentence(meanings:, from:, of:).tap { |lexeme| listed(lexeme.text, reason) }
  end

  def listed(text, reason = "fragment") = store.append([store::Entry.new(text:, reason:, note: nil)])

  def pruner(io: StringIO.new) = described_class.new(io:)

  def present?(lexeme) = Lexeme.exists?(lexeme.id)

  it "removes an untranslated reject when the word keeps another example" do
    other = examples(1).first
    doomed = rejected

    expect(pruner.call).to(eq({listed: 1, found: 1, protected: 0, spared: 0, removed: 1}))
    expect(present?(doomed)).to(be(false))
    expect(present?(other)).to(be(true))
    expect(present?(word)).to(be(true))
    expect(SentenceWord.where(sentence_id: other.id, lexeme_id: word.id).count).to(eq(1))
    expect(SentenceWord.where(sentence_id: doomed.id).count).to(eq(0))
  end

  it "spares an untranslated reject that is the only visible example of a word" do
    last = rejected

    expect(pruner.call).to(include(spared: 1, removed: 0))
    expect(present?(last)).to(be(true))
  end

  it "removes a translated reject when the word keeps three other examples in that language" do
    examples(3, meanings: {"en" => "It is."})
    doomed = rejected(meanings: {"en" => "It was."})

    expect(pruner.call).to(include(removed: 1))
    expect(present?(doomed)).to(be(false))
  end

  it "spares a translated reject when the word would keep only two examples in that language" do
    examples(2, meanings: {"en" => "It is."})
    examples(5)
    kept = rejected(meanings: {"en" => "It was."})

    expect(pruner.call).to(include(spared: 1, removed: 0))
    expect(present?(kept)).to(be(true))
  end

  it "spares a reject in two languages when only one of them would stay above the floor" do
    examples(2, meanings: {"en" => "It is.", "ru" => "Это так."})
    examples(1, meanings: {"en" => "It is."})
    kept = rejected(meanings: {"en" => "It was.", "ru" => "Было так."})

    expect(pruner.call).to(include(spared: 1, removed: 0))
    expect(present?(kept)).to(be(true))
  end

  it "counts a blank translation as no translation" do
    examples(3, meanings: {"en" => "It is."})
    examples(1, meanings: {"en" => "  "})
    doomed = rejected(meanings: {"en" => " ", "ru" => ""})

    expect(pruner.plan.removable).to(eq([doomed.id]))
  end

  it "lets only as many rejected examples of one word go as the floor allows" do
    examples(2, meanings: {"en" => "It is."})
    first, second, third = Array.new(3) { rejected(meanings: {"en" => "It was."}) }

    expect(pruner.call).to(include(found: 3, spared: 1, removed: 2))
    expect([first, second].map { |lexeme| present?(lexeme) }).to(eq([false, false]))
    expect(present?(third)).to(be(true))
  end

  it "keeps the last of several untranslated rejects of one word" do
    first, second = Array.new(2) { rejected }

    expect(pruner.call).to(include(spared: 1, removed: 1))
    expect(present?(first)).to(be(false))
    expect(present?(second)).to(be(true))
  end

  it "spares a reject shared by two words when either word would suffer" do
    lonely = Lexeme.create!(kind: :word, text: "孤")
    examples(4)
    shared = rejected(of: [word, lonely])

    expect(pruner.call).to(include(spared: 1, removed: 0))
    expect(present?(shared)).to(be(true))
  end

  it "removes a reject shared by two words when both keep enough examples" do
    other = Lexeme.create!(kind: :word, text: "手")
    examples(1)
    examples(1, of: other)
    shared = rejected(of: [word, other])

    expect(pruner.call).to(include(removed: 1))
    expect(present?(shared)).to(be(false))
  end

  it "removes a listed sentence that illustrates no word" do
    orphan = rejected(of: [])

    expect(pruner.call).to(include(removed: 1))
    expect(present?(orphan)).to(be(false))
  end

  {
    "someone studies it" => -> (lexeme) {
      LexemeMemory.create!(lexeme:, user: nil, facet: :recognition, activated_at: Time.current)
    },
    "someone reviewed it" => -> (lexeme) {
      elsewhere = Lexeme.create!(kind: :word, text: "憶")
      memory = LexemeMemory.create!(lexeme: elsewhere, user: nil, facet: :recognition, activated_at: Time.current)
      LexemeReview.create!(lexeme:, lexeme_memory: memory, rating: 3, reviewed_at: Time.current)
    },
    "someone practiced saying it" => -> (lexeme) { PronunciationAttempt.create!(lexeme:, user: nil) },
    "someone recorded it" => -> (lexeme) {
      PronunciationRecording.create!(lexeme:, user: FactoryBot.create(:user), text: lexeme.text, audio: "RIFF")
    },
    "a deck holds it" => -> (lexeme) {
      Collection.create!(name: "Trip", kind: :tocfl).add_lexeme(lexeme)
    },
    "a dictionary sense quotes it" => -> (lexeme) {
      sense = LexemeSense.create!(lexeme: Lexeme.create!(kind: :word, text: "句"), position: 0)
      SenseExample.create!(
        lexeme_sense: sense,
        content_source: lexeme.content_sources.first,
        lexeme:,
        text: lexeme.text
      )
    },
    "it carries senses of its own" => -> (lexeme) { LexemeSense.create!(lexeme:, position: 0) },
    "it is linked as a parent" => -> (lexeme) {
      LexemeLink.create!(parent: lexeme, child: Lexeme.create!(kind: :word, text: "子"), position: 0)
    },
    "it is linked as a child" => -> (lexeme) {
      LexemeLink.create!(parent: Lexeme.create!(kind: :word, text: "母"), child: lexeme, position: 0)
    }
  }.each do |reason, protect|
    it "never considers a reject when #{reason}" do
      examples(3)
      kept = rejected
      protect.call(kept)

      result = pruner.call

      expect(result).to(include(found: 1, protected: 1, spared: 0, removed: 0))
      expect(present?(kept)).to(be(true))
    end
  end

  %w[garbled pun crude false].each do |reason|
    it "removes a #{reason} reject even when it is the only translated example of its word" do
      last = rejected(meanings: {"en" => "It was."}, reason:)

      expect(pruner.call).to(include(spared: 0, removed: 1))
      expect(present?(last)).to(be(false))
    end
  end

  %w[fragment ambiguous off_corpus].each do |reason|
    it "keeps the floor for a #{reason} reject" do
      kept = rejected(meanings: {"en" => "It was."}, reason:)

      expect(pruner.call).to(include(spared: 1, removed: 0))
      expect(present?(kept)).to(be(true))
    end
  end

  it "still protects an unconditional reject someone studies" do
    studied = rejected(reason: "crude")
    LexemeMemory.create!(lexeme: studied, user: nil, facet: :recognition, activated_at: Time.current)

    expect(pruner.call).to(include(protected: 1, removed: 0))
    expect(present?(studied)).to(be(true))
  end

  it "counts an unconditional removal against the floor before sparing soft rejects" do
    examples(2, meanings: {"en" => "It is."})
    pun = rejected(meanings: {"en" => "A joke."}, reason: "pun")
    fragment = rejected(meanings: {"en" => "A scrap."})

    plan = pruner.plan

    expect(plan.removable).to(eq([pun.id]))
    expect(plan.spared).to(eq([fragment.id]))
    expect(plan.unconditional).to(eq([pun.id]))
  end

  it "leaves the entries listed as off_taiwan to the other task" do
    political = rejected(of: [], reason: "off_taiwan")

    expect(pruner.call).to(eq({listed: 0, found: 0, protected: 0, spared: 0, removed: 0}))
    expect(present?(political)).to(be(true))
  end

  it "never touches a sentence the store does not list" do
    stray = sentence(of: [])
    listed("早就不存在的句子", "garbled")

    expect(pruner.call).to(include(listed: 1, found: 0, removed: 0))
    expect(present?(stray)).to(be(true))
  end

  it "deletes nothing on a dry run and reports the numbers a real run would" do
    doomed = rejected
    kept = rejected

    dry = pruner.call(dry_run: true)

    expect(present?(doomed)).to(be(true))
    expect(present?(kept)).to(be(true))
    expect(pruner.call).to(eq(dry))
    expect(dry).to(eq({listed: 2, found: 2, protected: 0, spared: 1, removed: 1}))
  end

  it "plans untranslated rejects first, then translated ones, each by id" do
    examples(4, meanings: {"en" => "It is."})
    translated = rejected(meanings: {"en" => "It was."})
    untranslated = rejected
    kept = rejected(of: [Lexeme.create!(kind: :word, text: "孤")])
    studied = rejected
    LexemeMemory.create!(lexeme: studied, user: nil, facet: :recognition, activated_at: Time.current)

    plan = pruner.plan

    expect(plan.removable).to(eq([untranslated.id, translated.id]))
    expect(plan.spared).to(eq([kept.id]))
    expect(plan.protected).to(eq([studied.id]))
    expect(plan).to(be_frozen)
    expect(Lexeme.where(id: [translated.id, untranslated.id]).count).to(eq(2))
  end

  it "removes the profile and the source links of a removed sentence" do
    examples(1)
    doomed = rejected
    SentenceProfile.create!(lexeme: doomed)

    pruner.call

    expect(SentenceProfile.where(lexeme_id: doomed.id)).to(be_empty)
    expect(LexemeContentSource.where(lexeme_id: doomed.id)).to(be_empty)
    expect(LexemeContentSource.where(content_source_id: source.id)).to(exist)
  end

  it "does not count a sentence guests cannot see as an example" do
    examples(2, from: hidden)
    kept = rejected

    expect(pruner.call).to(include(spared: 1, removed: 0))
    expect(present?(kept)).to(be(true))
  end

  it "removes a listed sentence guests cannot see" do
    unseen = rejected(from: hidden)

    expect(pruner.call).to(include(removed: 1))
    expect(present?(unseen)).to(be(false))
  end

  it "reports what it found and what it would remove" do
    rejected
    rejected
    io = StringIO.new

    described_class.new(io:).call(dry_run: true)

    expect(io.string).to(include("listed 2", "present in the corpus 2", "to remove 1", "last examples of a word: 1"))
  end
end
