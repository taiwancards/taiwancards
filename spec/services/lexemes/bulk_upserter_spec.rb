# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::BulkUpserter do
  subject(:upserter) { described_class.new }

  def entry(text, **attrs) = described_class::Entry.new(kind: :word, text:, **attrs)

  def statements
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless payload[:name].in?(["SCHEMA", "TRANSACTION"]) || payload[:cached]
    end

    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it "creates the words the dictionary has never seen" do
    result = upserter.call([entry("珍奶", readings: {"pinyin" => "zhēnnǎi"}), entry("雞排")])

    expect(result.inserted).to(eq(2))
    expect(Lexeme.find_by(text: "珍奶").readings["pinyin"]).to(eq("zhēnnǎi"))
    expect(Lexeme.find_by(text: "雞排").kind).to(eq("word"))
  end

  it "merges into the entry a classifier has since moved to collocation" do
    existing = create(:lexeme, kind: :collocation, text: "超商", meanings: {"en" => "convenience store"})

    result = upserter.call(
      [entry("超商", readings: {"pinyin" => "chāoshāng"}, meanings: {"ru" => "круглосуточный"})]
    )

    expect(result).to(have_attributes(inserted: 0, updated: 1))
    expect(existing.reload.kind).to(eq("collocation"))
    expect(existing.readings["pinyin"]).to(eq("chāoshāng"))
    expect(existing.meanings).to(eq({"en" => "convenience store", "ru" => "круглосуточный"}))
    expect(Lexeme.where(text: "超商").count).to(eq(1))
  end

  it "prefers the word when a text exists under both kinds" do
    word = create(:lexeme, kind: :word, text: "小七")
    collocation = create(:lexeme, kind: :collocation, text: "小七", meanings: {"en" => "untouched"})

    upserter.call([entry("小七", meanings: {"en" => "7-Eleven"})])

    expect(word.reload.meanings["en"]).to(eq("7-Eleven"))
    expect(collocation.reload.meanings["en"]).to(eq("untouched"))
  end

  it "leaves a row that already says the same thing alone" do
    lexeme = create(:lexeme, kind: :word, text: "捷運", meanings: {"en" => "metro"}, sources: ["Common words"])
    before = lexeme.updated_at

    result = upserter.call([entry("捷運", meanings: {"en" => "metro"}, source: "Common words")])

    expect(result).to(have_attributes(inserted: 0, updated: 0, unchanged: 1))
    expect(lexeme.reload.updated_at).to(eq(before))
  end

  it "adds a source without dropping the ones already there" do
    lexeme = create(:lexeme, kind: :word, text: "颱風", sources: ["TBCL 3"])

    upserter.call([entry("颱風", source: "Common words")])

    expect(lexeme.reload.sources).to(eq(["TBCL 3", "Common words"]))
  end

  it "runs the save callbacks so search text and tier are filled in" do
    upserter.call([entry("拳擊", readings: {"pinyin" => "quánjí"}, meanings: {"en" => "boxing"})])

    lexeme = Lexeme.find_by(text: "拳擊")
    expect(lexeme.search_text).to(include("boxing"))
    expect(lexeme.tier).to(be_present)
  end

  it "reuses the row it just built when a text repeats inside one batch" do
    upserter.call(
      [
        entry("滷肉飯", meanings: {"en" => "braised pork rice"}),
        entry("滷肉飯", readings: {"pinyin" => "lǔròufàn"})
      ]
    )

    expect(Lexeme.where(text: "滷肉飯").count).to(eq(1))
    expect(Lexeme.find_by(text: "滷肉飯").readings["pinyin"]).to(eq("lǔròufàn"))
  end

  it "skips blank text" do
    expect(upserter.call([entry(""), entry(" ")])).to(have_attributes(inserted: 0, updated: 0, unchanged: 0))
  end

  it "reads the batch once and writes it once, whatever its size" do
    create(:lexeme, kind: :word, text: "台北")
    batch = (1..60).map { |n| entry("測試#{n}") } + [entry("台北", meanings: {"en" => "Taipei"})]

    expect(statements { upserter.call(batch) }).to(eq(3))
  end
end
