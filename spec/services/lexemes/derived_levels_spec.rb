# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::DerivedLevels do
  after { Huayu::TextAnalyzer.reset_vocabulary! }

  def character(text, tbcl: nil, tocfl: nil)
    create(:lexeme, kind: :character, text:, data: {"tbcl_grade" => tbcl, "tocfl_level" => tocfl}.compact)
  end

  def run
    described_class.new(io: StringIO.new).call
  end

  it "derives a level for a word from the characters it is written with" do
    character("甲", tbcl: 2)
    character("乙", tbcl: 3)
    word = create(:lexeme, kind: :word, text: "甲乙")

    run

    expect(word.reload.data["tbcl"]).to(eq(3))
    expect(word.data["tbcl_exact"]).to(be(true))
  end

  it "files a long term where most of it sits" do
    %w[甲 乙 丙].each { |text| character(text, tbcl: 2) }
    character("丁", tbcl: 4)
    word = create(:lexeme, kind: :word, text: "甲乙丙丁")

    run

    expect(word.reload.data["tbcl"]).to(eq(2))
    expect(word.data["tbcl_exact"]).to(be(false))
  end

  it "never derives a word's level from its own official grade" do
    character("甲", tbcl: 5)
    character("乙", tbcl: 5)
    word = create(:lexeme, kind: :word, text: "甲乙", data: {"tbcl_grade" => "1"})

    run

    expect(word.reload.data["tbcl"]).to(eq(5))
  end

  it "leaves a word ungraded when its characters carry no level" do
    character("甲")
    character("乙")
    word = create(:lexeme, kind: :word, text: "甲乙")

    run

    expect(word.reload.data["tbcl"]).to(be_nil)
    expect(word.data["tbcl_exact"]).to(be(false))
  end

  it "carries the TOCFL level over from the TBCL grade when the TOCFL lists say nothing" do
    character("甲", tbcl: 2)
    character("乙", tbcl: 2)
    word = create(:lexeme, kind: :word, text: "甲乙", data: {"tbcl_grade" => "5"})

    run

    expect(word.reload.data["tocfl"]).to(eq(6))
    expect(word.data["tocfl_exact"]).to(be(false))
    expect(word.data["tocfl_via"]).to(eq(5))
  end

  it "prefers the TOCFL lists over the carried grade" do
    character("甲", tocfl: "A1", tbcl: 5)
    character("乙", tocfl: "A1", tbcl: 5)
    word = create(:lexeme, kind: :word, text: "甲乙", data: {"tbcl_grade" => "5"})

    run

    expect(word.reload.data["tocfl"]).to(eq(3))
    expect(word.data["tocfl_via"]).to(be_nil)
  end
end
