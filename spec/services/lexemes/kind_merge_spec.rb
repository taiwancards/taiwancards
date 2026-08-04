# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::KindMerge do
  def merge = described_class.new(io: StringIO.new).call

  it "leaves a dictionary alone when nothing is kept twice" do
    create(:lexeme, kind: :word, text: "咖啡")
    create(:lexeme, kind: :collocation, text: "喝咖啡")

    expect(described_class.new(io: StringIO.new).drift?).to(be(false))
    expect(merge.merged).to(eq(0))
  end

  it "folds the later copy into the one the rest of the database already points at" do
    keeper = create(:lexeme, kind: :collocation, text: "超商", meanings: {"en" => "convenience store"})
    loser = create(:lexeme, kind: :word, text: "超商", readings: {"pinyin" => "chāoshāng"}, meanings: {})

    expect(merge.merged).to(eq(1))

    expect(Lexeme.where(text: "超商").pluck(:id)).to(eq([keeper.id]))
    expect(Lexeme.exists?(loser.id)).to(be(false))
    expect(keeper.reload.readings["pinyin"]).to(eq("chāoshāng"))
    expect(keeper.meanings["en"]).to(eq("convenience store"))
  end

  it "lets whichever copy an importer wrote most recently win the fields they share" do
    keeper = create(
      :lexeme,
      kind: :collocation,
      text: "萊爾富",
      data: {"tier" => 2, "tbcl_grade" => 4},
      updated_at: 2.days.ago
    )
    create(:lexeme, kind: :word, text: "萊爾富", data: {"tier" => 1, "rank" => 1}, updated_at: 1.minute.ago)

    merge

    expect(keeper.reload.data).to(include("tier" => 1, "rank" => 1, "tbcl_grade" => 4))
  end

  it "does not let a copy nobody has touched in years undo a recent enrichment" do
    keeper = create(
      :lexeme,
      kind: :collocation,
      text: "手搖飲",
      meanings: {"ru" => "чайная лавка"},
      updated_at: 1.minute.ago
    )
    create(
      :lexeme,
      kind: :word,
      text: "手搖飲",
      meanings: {"ru" => "старый перевод"},
      updated_at: 2.years.ago
    )

    merge

    expect(keeper.reload.meanings["ru"]).to(eq("чайная лавка"))
  end

  it "carries the collection membership of the copy it removes" do
    keeper = create(:lexeme, kind: :collocation, text: "小七")
    loser = create(:lexeme, kind: :word, text: "小七")
    collection = Collection.create!(kind: :everyday, name: "Taiwan everyday", position: 900)
    collection.add_lexeme(loser, position: 7)

    merge

    expect(collection.lexemes.reload.pluck(:id)).to(eq([keeper.id]))
  end

  it "keeps the sentences the copy was an example of, without tripping over the ones already there" do
    keeper = create(:lexeme, kind: :collocation, text: "珍奶")
    loser = create(:lexeme, kind: :word, text: "珍奶")
    source = ContentSource.create!(slug: "merge_spec", name: "Merge spec", license_name: "CC BY 4.0")
    shared = create(:lexeme, kind: :sentence, text: "我要一杯珍奶", content_sources: [source])
    only_loser = create(:lexeme, kind: :sentence, text: "珍奶好喝", content_sources: [source])
    SentenceWord.insert_all(
      [
        {sentence_id: shared.id, lexeme_id: keeper.id, gdex: 5},
        {sentence_id: shared.id, lexeme_id: loser.id, gdex: 9},
        {sentence_id: only_loser.id, lexeme_id: loser.id, gdex: 4}
      ]
    )

    merge

    expect(SentenceWord.where(lexeme_id: keeper.id).pluck(:sentence_id)).to(match_array([shared.id, only_loser.id]))
    expect(SentenceWord.where(lexeme_id: loser.id)).to(be_empty)
  end

  it "moves the characters the copy was linked to" do
    keeper = create(:lexeme, kind: :collocation, text: "統編")
    loser = create(:lexeme, kind: :word, text: "統編")
    child = create(:lexeme, :character, text: "統")
    LexemeLink.create!(parent: loser, child: child, position: 0)

    merge

    expect(LexemeLink.where(parent_id: keeper.id).pluck(:child_id)).to(eq([child.id]))
  end
end
