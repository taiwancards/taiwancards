# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::MedicineImporter do
  let(:path) { Rails.root.join("tmp/medicine_importer_spec.json") }

  def write(entries)
    path.write(entries.to_json)
  end

  def base(text, extra = {})
    {
      "text" => text,
      "pinyin" => "cè shì",
      "en" => "test",
      "ru" => "тест",
      "category" => "hospital"
    }.merge(extra)
  end

  after { path.delete if path.exist? }

  it "is idempotent and files entries under their category" do
    write([base("測試醫甲"), base("測試醫乙", "category" => "organs", "tier" => 1, "marked" => true)])

    first = described_class.new(path:).call
    count = Lexeme.count
    second = described_class.new(path:).call

    expect(first.imported).to(eq(2))
    expect(second.imported).to(eq(2))
    expect(Lexeme.count).to(eq(count))
    organ = Lexeme.find_by!(text: "測試醫乙")
    expect(organ.data["med"]).to(include("category" => "organs", "tier" => 1))
    expect(organ.data["taiwan_only"]).to(be(true))
    expect(organ.data["tier"]).to(eq(1))
  end

  it "keeps everyday-owned readings, meanings and notes while adding the medicine placement" do
    everyday = Rails.root.join("tmp/medicine_importer_everyday_spec.json")
    everyday.write(
      [
        {
          "text" => "測試醫丙",
          "pinyin" => "yuán yǒu",
          "en" => "everyday gloss",
          "origin" => "taiwan-mandarin",
          "register" => "casual",
          "domain" => "health",
          "note_en" => "everyday note",
          "examples" => [{"zh" => "既有例句。", "en" => "old"}]
        }
      ].to_json
    )
    Huayu::TaiwanEverydayImporter.new(path: everyday).call

    write(
      [
        base(
          "測試醫丙",
          "en" => "medicine gloss",
          "register" => "neutral",
          "note_en" => "medicine note",
          "examples" => [{"zh" => "新例句。", "en" => "new"}]
        )
      ]
    )
    described_class.new(path:).call

    lexeme = Lexeme.find_by!(text: "測試醫丙")
    expect(lexeme.meaning(:en)).to(eq("everyday gloss"))
    expect(lexeme.readings["pinyin"]).to(eq("yuán yǒu"))
    expect(lexeme.data.dig("note", "en")).to(eq("everyday note"))
    expect(lexeme.data["register"]).to(eq("casual"))
    expect(lexeme.data["med"]).to(include("category" => "hospital"))
    expect(lexeme.data["examples"].map { |row| row["zh"] }).to(contain_exactly("既有例句。", "新例句。"))
  ensure
    everyday.delete if everyday.exist?
  end

  it "stores folk and formal counterparts and the Hokkien reading" do
    write(
      [
        base("測試醫丁", "folk" => "測試醫戊"),
        base(
          "測試醫戊",
          "formal" => "測試醫丁",
          "origin" => "hokkien",
          "register" => "casual",
          "tailo" => "chhì-giām",
          "hokkien" => "試驗"
        )
      ]
    )

    described_class.new(path:).call

    expect(Lexeme.find_by!(text: "測試醫丁").data.dig("med", "folk")).to(eq("測試醫戊"))
    folk = Lexeme.find_by!(text: "測試醫戊")
    expect(folk.data.dig("med", "formal")).to(eq("測試醫丁"))
    expect(folk.data["hokkien"]).to(eq({"tailo" => "chhì-giām", "hanzi" => "試驗"}))
  end

  it "refuses to prune when the source shrinks implausibly" do
    write(Array.new(20) { |i| base("測試醫#{i}") })
    described_class.new(path:).call
    collection = Collection.find_by!(kind: :medicine)
    expect(collection.collection_items.count).to(eq(20))

    write([base("測試醫0")])
    result = described_class.new(path:).call

    expect(result.dropped).to(eq(0))
    expect(collection.collection_items.count).to(eq(20))
  end

  it "skips malformed entries instead of failing the whole import" do
    write([base("測試醫己"), {"text" => "壞", "pinyin" => "huài", "en" => "bad", "category" => "nope"}])

    result = described_class.new(path:).call

    expect(result.imported).to(eq(1))
    expect(result.skipped).to(eq(1))
  end
end
