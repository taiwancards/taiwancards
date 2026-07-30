# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::LiangciImporter do
  it "writes the pair index in both directions from one source" do
    noun = create(:lexeme, kind: :word, text: "貓", meanings: {"en" => "cat"})
    importer = described_class.new

    importer.call

    entry = Lexeme.find_by(kind: :measure_word, text: "隻")
    expect(entry).to(be_present)
    expect(entry.data["nouns"]).to(include("貓"))

    classifiers = noun.reload.data["classifiers"].map { |row| row["text"] }
    expect(classifiers).to(include("隻"))
    expect(noun.data["classifiers"].first["main"]).to(be(true))
  end

  it "ranks measure words among themselves by how often they really count something" do
    described_class.new.call

    common = Lexeme.find_by(kind: :measure_word, text: "個")
    rare = Lexeme.find_by(kind: :measure_word, text: "綹")

    expect(common.score).to(be < rare.score)
    expect(Lexeme.where(kind: :measure_word).where(score: nil)).to(be_empty)
  end

  it "runs twice without changing anything the second time" do
    importer = described_class.new
    importer.call
    before = Lexeme.where(kind: :measure_word).order(:text).pluck(:text, :score, :data)

    described_class.new.call

    after = Lexeme.where(kind: :measure_word).order(:text).pluck(:text, :score, :data)
    expect(after).to(eq(before))
  end
end
