# frozen_string_literal: true

require "rails_helper"

RSpec.describe Study::CardSet do
  let(:user) { create(:user) }

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

  before do
    Current.user = user
    user.update!(prefs: user.prefs.merge("level" => "3"))
  end

  after { Current.user = nil }

  def grammar_point(pattern, level)
    create(
      :lexeme,
      kind: :grammar,
      text: pattern,
      meanings: {"en" => "the #{pattern} pattern"},
      data: {"tbcl_grade" => level, "grammar_slug" => "slug-#{pattern}", "head" => pattern, "facets" => ["recognition"]}
    )
  end

  def known_word(text)
    word = create(:lexeme, kind: :word, text:)
    LexemeMemory.create!(lexeme: word, facet: :recognition, user:, state: :review, activated_at: 1.day.ago)
    word
  end

  def voiced_sentence(text, words:, level: 1, audio: "common_voice")
    sentence = Lexeme.new(
      kind: :sentence,
      text:,
      meanings: {"en" => "a translated sentence"},
      data: {"audio" => audio, "difficulty" => 100}.compact
    )
    sentence.lexeme_content_sources.build(content_source: source)
    sentence.save!
    SentenceProfile.create!(lexeme: sentence, tocfl_index: level, tbcl_index: level, difficulty: 100)
    words.each { |word| SentenceWord.create!(sentence:, lexeme: word, gdex: 500) }
    sentence
  end

  it "mixes grammar into the recommended sitting" do
    grammar_point("V了1", 1)

    ids = described_class.new.select(mode: "daily", size: 20)

    expect(Lexeme.where(id: ids).where(kind: :grammar)).to(be_any)
  end

  it "still finds room for grammar when a backlog of unseen words is waiting" do
    grammar_point("V了1", 1)
    30.times do |n|
      word = create(:lexeme, kind: :word, text: "詞彙#{n}", data: {"tbcl_grade" => 1})
      LexemeMemory.create!(lexeme: word, facet: :recognition, user:, state: :unseen, activated_at: 1.day.ago)
    end

    ids = described_class.new.select(mode: "daily", size: 20)

    expect(Lexeme.where(id: ids).where(kind: :grammar)).to(be_any)
  end

  it "leaves grammar out of a personal deck sitting" do
    grammar_point("V了1", 1)
    deck = Collection.create!(kind: :manual, name: "Mine", user:)
    deck.add_lexeme(create(:lexeme, kind: :word, text: "學校"))

    ids = described_class.new.select(mode: "collection", collection: deck)

    expect(Lexeme.where(id: ids).where(kind: :grammar)).to(be_empty)
  end

  it "offers a voiced sentence once every word in it is known" do
    known = known_word("喝")
    other = known_word("咖啡")
    sentence = voiced_sentence("我喝咖啡。", words: [known, other])

    ids = described_class.new.select(mode: "daily", size: 20)

    expect(ids).to(include(sentence.id))
  end

  it "holds a sentence back while one of its words is still unknown" do
    known = known_word("喝")
    unknown = create(:lexeme, kind: :word, text: "紅茶")
    sentence = voiced_sentence("我喝紅茶。", words: [known, unknown])

    ids = described_class.new.select(mode: "daily", size: 20)

    expect(ids).not_to(include(sentence.id))
  end

  it "holds back a sentence that has no recording" do
    silent = voiced_sentence("我喝水。", words: [known_word("喝")], audio: nil)

    ids = described_class.new.select(mode: "daily", size: 20)

    expect(ids).not_to(include(silent.id))
  end

  it "holds back a sentence graded above the level the learner is working toward" do
    hard = voiced_sentence("我喝咖啡。", words: [known_word("喝")], level: 6)

    ids = described_class.new.select(mode: "daily", size: 20)

    expect(ids).not_to(include(hard.id))
  end

  it "offers the easiest readable sentences first" do
    word = known_word("喝")
    later = voiced_sentence("我想喝。", words: [word], level: 3)
    sooner = voiced_sentence("我喝。", words: [word], level: 1)

    ids = described_class.new.select(mode: "daily", size: 7)

    expect(ids & [sooner.id, later.id]).to(eq([sooner.id]))
  end

  it "holds back a sentence the learner has no word for" do
    stray = voiced_sentence("你好。", words: [])

    ids = described_class.new.select(mode: "daily", size: 20)

    expect(ids).not_to(include(stray.id))
  end
end
