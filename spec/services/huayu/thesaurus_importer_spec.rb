# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ThesaurusImporter do
  let(:path) { Rails.root.join("tmp/spec-thesaurus.json") }

  before do
    path.write(
      {
        "高興" => {
          "synonyms" => %w[快樂 怡悅],
          "antonyms" => %w[傷心],
          "related" => [{"word" => "失望", "score" => 0.4}, {"word" => "沒有這個詞", "score" => 0.3}],
          "collocates" => [{"word" => "非常", "dice" => 9.1}]
        }
      }.to_json
    )
  end

  after { path.delete if path.exist? }

  it "keeps only the relations whose other side is in our dictionary" do
    target = create(:lexeme, kind: :word, text: "高興", meanings: {"en" => "glad"})
    %w[快樂 傷心 失望 非常].each { |text| create(:lexeme, kind: :word, text:) }

    described_class.new(path:).call

    data = target.reload.data
    expect(data["synonyms"]).to(eq(%w[快樂]))
    expect(data["antonyms"]).to(eq(%w[傷心]))
    expect(data["related"]).to(eq(%w[失望]))
    expect(data["collocates"]).to(eq(%w[非常]))
  end

  it "drops relations that disappeared from the source" do
    target = create(
      :lexeme,
      kind: :word,
      text: "學校",
      data: {"synonyms" => %w[書院], "tbcl_grade" => "1"}
    )

    described_class.new(path:).call

    expect(target.reload.data).not_to(have_key("synonyms"))
    expect(target.data["tbcl_grade"]).to(eq("1"))
  end
end
