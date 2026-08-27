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
end
