# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SentenceCorrectionRepair do
  let(:corrections) {
    {
      "倒底在期待什麼" => "到底在期待什麼",
      "下列那一組的字義相同？" => "下列哪一組的字義相同？"
    }
  }

  let!(:source) do
    ContentSource.create!(
      slug: "common_voice",
      name: "Common Voice",
      license_commercial: true,
      register: :colloquial,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Common Voice."
    )
  end

  def sentence(text, meanings: {}, data: {})
    lexeme = Lexeme.new(kind: :sentence, text:, meanings:, data: {"length" => text.scan(/\p{Han}/).length}.merge(data))
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  def repair(rejected: Set.new) = described_class.new(corrections:, rejected:)

  it "corrects a misspelt transcript and keeps its translations and its recording" do
    lexeme = sentence(
      "倒底在期待什麼",
      meanings: {"en" => "What are you expecting?", "ja" => "何を期待してるの"},
      data: {"audio" => "common_voice"}
    )

    result = repair.call

    expect(result.corrected).to(eq(1))
    expect(lexeme.reload.text).to(eq("到底在期待什麼"))
    expect(lexeme.meanings).to(eq({"en" => "What are you expecting?", "ja" => "何を期待してるの"}))
    expect(lexeme.data["audio"]).to(eq("common_voice"))
    expect(lexeme.data["segments"].join).to(eq("到底在期待什麼"))
    expect(repair.drift?).to(be(false))
  end

  it "merges into the sentence that already has the correct text" do
    keeper = sentence("下列哪一組的字義相同？", meanings: {"en" => "Which group has the same meaning?"})
    misspelt = sentence("下列那一組的字義相同？", meanings: {"vi" => "Nhóm nào cùng nghĩa?"})

    result = repair.call

    expect(result.merged).to(eq(1))
    expect(Lexeme.exists?(misspelt.id)).to(be(false))
    expect(keeper.reload.meanings).to(
      eq({"en" => "Which group has the same meaning?", "vi" => "Nhóm nào cùng nghĩa?"})
    )
  end

  it "leaves a rejected sentence to the reject list" do
    lexeme = sentence("倒底在期待什麼")

    expect(repair(rejected: Set["倒底在期待什麼"]).drift?).to(be(false))
    expect(lexeme.reload.text).to(eq("倒底在期待什麼"))
  end
end
