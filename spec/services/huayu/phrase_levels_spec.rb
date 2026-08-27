# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::PhraseLevels do
  after { Huayu::TextAnalyzer.reset_vocabulary! }

  def phrase(text, **data)
    create(:lexeme, kind: :phrase, text:, restricted: true, data: {"drill" => 1}.merge(data))
  end

  def word(text, tocfl: nil, tbcl: nil)
    create(:lexeme, kind: :word, text:, data: {"tocfl_level" => tocfl, "tbcl_grade" => tbcl}.compact)
  end

  it "takes the lowest level that covers the sentence" do
    word("我", tocfl: "Novice1", tbcl: 1)
    word("很", tocfl: "Novice1", tbcl: 1)
    word("好", tocfl: "Novice1", tbcl: 1)
    Huayu::TextAnalyzer.reset_vocabulary!
    phrase("我很好。")

    described_class.new(io: StringIO.new).call

    drill = Lexeme.practice_phrases.first
    expect(drill.data["tocfl"]).to(eq(1))
    expect(drill.data["tbcl"]).to(eq(1))
    expect(drill.data["tocfl_exact"]).to(be(true))
  end

  it "files a phrase where most of it sits, marking it inexact" do
    %w[甲 乙 丙 丁 戊 己 庚].each { |text| word(text, tbcl: 2) }
    word("辛", tbcl: 4)
    Huayu::TextAnalyzer.reset_vocabulary!
    phrase("甲乙丙丁戊己庚辛。")

    described_class.new(io: StringIO.new).call

    drill = Lexeme.practice_phrases.first
    expect(drill.data["tbcl"]).to(eq(2))
    expect(drill.data["tbcl_exact"]).to(be(false))
  end

  it "refuses the lower level when a word sits more than two levels above it" do
    %w[甲 乙 丙 丁 戊 己 庚].each { |text| word(text, tbcl: 2) }
    word("辛", tbcl: 7)
    Huayu::TextAnalyzer.reset_vocabulary!
    phrase("甲乙丙丁戊己庚辛。")

    described_class.new(io: StringIO.new).call

    drill = Lexeme.practice_phrases.first
    expect(drill.data["tbcl"]).to(eq(5))
    expect(drill.data["tbcl_exact"]).to(be(false))
  end

  it "leaves a sentence ungraded when too much of it is unlisted" do
    word("低", tbcl: 1)
    Huayu::TextAnalyzer.reset_vocabulary!
    phrase("低生僻詞彙難字。")

    described_class.new(io: StringIO.new).call

    expect(Lexeme.practice_phrases.first.data["tbcl"]).to(be_nil)
  end

  it "links a sentence to its words and characters, and never the other way around" do
    晚餐 = word("晚餐")
    Huayu::TextAnalyzer.reset_vocabulary!
    drill = phrase("晚餐。")

    result = described_class.new(io: StringIO.new).call

    expect(result[:linked]).to(eq(1))
    expect(drill.reload.components).to(eq([晚餐]))
    expect(晚餐.reload.containers).to(be_empty)
    expect(晚餐.containing_words).to(be_empty)
  end

  it "covers textbook sentences as well as the drills" do
    word("我")
    Huayu::TextAnalyzer.reset_vocabulary!
    phrase("我。")
    create(:lexeme, kind: :phrase, text: "我我。", restricted: true, data: {"sentence" => true})

    result = described_class.new(io: StringIO.new).call

    expect(result[:phrases]).to(eq(2))
  end

  it "rewrites its own links instead of piling new ones on top" do
    word("晚餐")
    Huayu::TextAnalyzer.reset_vocabulary!
    drill = phrase("晚餐。")

    described_class.new(io: StringIO.new).call
    described_class.new(io: StringIO.new).call

    expect(drill.reload.child_links.count).to(eq(1))
  end
end
