# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::VisitedPages do
  def page(address, verb = nil) = described_class.new([[address, verb]]).fetch(address, verb)

  it "shows a character page and a dictionary entry as the characters themselves" do
    expect(page("/characters/%E9%9B%B6")).to(
      have_attributes(path: "/characters/零", label: nil, href: "/characters/%E9%9B%B6")
    )
    expect(page("/dict/%E5%85%A7").path).to(eq("/dict/內"))
  end

  it "labels a sentence page with the sentence" do
    sentence = create(:lexeme, :sentence, text: "我今天很忙。")

    expect(page("/sentences/#{sentence.public_id}")).to(have_attributes(label: "我今天很忙。", hidden: false))
    expect(page("/sentences/#{sentence.id}").label).to(eq("我今天很忙。"))
  end

  it "shortens a long label for the row and keeps it whole for the title" do
    text = "#{"很長的句子" * 30}。"
    sentence = create(:lexeme, :sentence, text:)
    shown = page("/sentences/#{sentence.public_id}")

    expect(shown.short_label.length).to(eq(described_class::LABEL_LIMIT))
    expect(shown.title).to(start_with(text))
  end

  it "labels a grammar lesson with the Mandarin pattern it teaches" do
    lesson = Huayu::GrammarLessons.all.first

    expect(page("/grammar/#{lesson.slug}").label).to(eq(lesson.pattern))
  end

  it "recognizes a route behind a locale prefix and a query string" do
    lesson = Huayu::GrammarLessons.all.first
    shown = page("https://study.example/ru/grammar/#{lesson.slug}?from=%E9%9B%B6")

    expect(shown).to(have_attributes(path: "/ru/grammar/#{lesson.slug}?from=零", label: lesson.pattern))
    expect(shown.href).to(eq("https://study.example/ru/grammar/#{lesson.slug}?from=%E9%9B%B6"))
  end

  it "shows the decoded path alone for a deleted record" do
    sentence = create(:lexeme, :sentence)
    address = "/sentences/#{sentence.public_id}"
    sentence.destroy!

    expect(page(address)).to(have_attributes(path: address, label: nil))
  end

  it "shows the decoded path alone for an unknown route and does not link it" do
    expect(page("/nowhere/%E9%9B%B6")).to(have_attributes(path: "/nowhere/零", label: nil, href: nil))
    expect(page("javascript:alert(1)").href).to(be_nil)
  end

  it "keeps the static site marker and links to the same page in the app" do
    expect(page("site:/characters/%E9%9B%B6")).to(
      have_attributes(path: "site:/characters/零", href: "/characters/%E9%9B%B6")
    )
  end

  it "labels a form submission but links only to an address that opens with GET" do
    text = Graded::Library.texts(Graded::Levels.ids.first).first

    submitted = page("/graded/#{text.tier}/#{text.id}/done", "POST")
    expect(submitted.label).to(be_present)
    expect(submitted.href).to(be_nil)
    expect(page("/reader", "POST").href).to(eq("/reader"))
  end

  it "names only the kind of page for a learner's own text and deck" do
    owner = create(:user)
    text = ReadingText.create!(user: owner, title: "My diary", body: "今天很累", kind: :article)
    story = ReadingText.create!(title: "小故事", body: "故事", kind: :story)
    deck = Collection.create!(user: owner, name: "Secret deck", kind: :manual)

    expect(page("/reader/#{text.id}")).to(
      have_attributes(label: I18n.t("admin_pages.own_text"), hidden: true, href: nil)
    )
    expect(page("/desks/#{deck.id}")).to(
      have_attributes(label: I18n.t("admin_pages.own_deck"), hidden: true, href: nil)
    )
    expect(page("/stories/#{story.id}").label).to(eq("小故事"))
  end

  it "masks tokens the app filters from its logs and does not link them" do
    expect(page("/l/abc123secret")).to(have_attributes(path: "/l/[FILTERED]", href: nil))
  end

  it "resolves each kind of record with one query for a whole page of rows" do
    sentences = create_list(:lexeme, 3, :sentence)
    texts = 2.times.map { |n| ReadingText.create!(title: "故事#{n}", body: "故事", kind: :story) }
    addresses = [
      *sentences.map { |sentence| "/sentences/#{sentence.public_id}" },
      *texts.map { |text| "/stories/#{text.id}" },
      *texts.map { |text| "/reader/#{text.id}" },
      "/grammar/zhe-na-na",
      "/characters/%E9%9B%B6"
    ]

    pages = described_class.new(addresses)
    report = count_queries { addresses.each { |address| pages.fetch(address) } }

    expect(report.count).to(eq(2))
    expect(addresses.map { |address| pages.fetch(address).label }.compact.length).to(eq(8))
  end
end
