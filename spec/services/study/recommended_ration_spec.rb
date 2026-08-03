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

  def voiced_sentence(text, words:, level: 1)
    sentence = Lexeme.new(
      kind: :sentence,
      text:,
      meanings: {"en" => "a translated sentence"},
      data: {"tbcl_grade" => level, "audio" => "common_voice"}
    )
    sentence.lexeme_content_sources.build(content_source: source)
    sentence.save!
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
    known = known_word("喝")
    silent = Lexeme.new(
      kind: :sentence,
      text: "我喝水。",
      meanings: {"en" => "I drink water."},
      data: {"tbcl_grade" => 1}
    )
    silent.lexeme_content_sources.build(content_source: source)
    silent.save!
    SentenceWord.create!(sentence: silent, lexeme: known, gdex: 500)

    ids = described_class.new.select(mode: "daily", size: 20)

    expect(ids).not_to(include(silent.id))
  end
end
