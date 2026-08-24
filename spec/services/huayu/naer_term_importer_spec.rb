# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::NaerTermImporter do
  let(:path) { Rails.root.join("tmp/naer_term_importer_spec.json") }

  def write(entries)
    path.write(entries.to_json)
  end

  def entry(text, extra = {})
    {
      "text" => text,
      "zhuyin" => "ㄘㄜˋ ㄕˋ",
      "pinyin" => "cèshì",
      "en" => "a test term",
      "ru" => "проверочный термин",
      "domain" => "signage",
      "tags" => []
    }.merge(extra)
  end

  def run = described_class.new(io: StringIO.new, path:).call

  after { path.delete if path.exist? }

  it "adds a term with its reading and both glosses" do
    write([entry("測試臺甲")])

    expect(run[:created]).to(eq(1))

    lexeme = Lexeme.find_by!(kind: :word, text: "測試臺甲")
    expect(lexeme.readings).to(eq("pinyin" => "cèshì", "zhuyin" => "ㄘㄜˋ ㄕˋ"))
    expect(lexeme.meanings).to(eq("en" => "a test term", "ru" => "проверочный термин"))
    expect(lexeme.sources).to(eq(["NAER terms"]))
    expect(lexeme.data["domain"]).to(eq("places"))
  end

  it "refreshes a term it owns when the file gains a better gloss" do
    write([entry("測試臺乙")])
    run

    write([entry("測試臺乙", "ru" => "уточнённый перевод")])

    expect(run[:updated]).to(eq(1))
    expect(Lexeme.find_by!(text: "測試臺乙").meanings["ru"]).to(eq("уточнённый перевод"))
  end

  it "drops the stale origin marker left by earlier imports" do
    write([entry("測試臺丙")])
    run
    lexeme = Lexeme.find_by!(text: "測試臺丙")
    lexeme.update_column(:data, lexeme.data.merge("origin" => "naer"))

    run

    expect(lexeme.reload.data).not_to(have_key("origin"))
  end

  it "leaves a word that belongs to another source alone" do
    create(:lexeme, kind: :word, text: "測試臺丁", meanings: {"en" => "owned elsewhere"}, sources: ["Common words"])

    write([entry("測試臺丁")])
    result = run

    expect(result[:created]).to(eq(0))
    expect(result[:updated]).to(eq(0))
    expect(Lexeme.find_by!(text: "測試臺丁").meanings["en"]).to(eq("owned elsewhere"))
  end
end
