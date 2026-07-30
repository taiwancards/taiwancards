# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::TaiwanEverydayImporter do
  let(:path) { Rails.root.join("tmp/everyday_importer_spec.json") }
  let(:user) { create(:user) }

  def write(entries)
    path.write(entries.to_json)
  end

  def base(text, extra = {})
    {
      "text" => text,
      "pinyin" => "cè shì",
      "en" => "test",
      "origin" => "taiwan-mandarin",
      "register" => "neutral",
      "domain" => "life"
    }.merge(extra)
  end

  after { path.delete if path.exist? }

  it "is idempotent: running twice creates nothing extra" do
    write([base("測試甲"), base("測試乙")])

    first = described_class.new(path:).call
    count_after_first = Lexeme.count
    second = described_class.new(path:).call

    expect(first.imported).to(eq(2))
    expect(second.imported).to(eq(2))
    expect(Lexeme.count).to(eq(count_after_first))
  end

  it "updates a changed meaning without touching the user's progress" do
    write([base("測試甲")])
    described_class.new(path:).call
    lexeme = Lexeme.find_by!(text: "測試甲")
    memory = LexemeMemory.create!(
      user:,
      lexeme:,
      facet: "recognition",
      state: :review,
      stability: 12.0,
      due_at: 3.days.from_now,
      activated_at: 1.day.ago
    )

    write([base("測試甲", "en" => "changed meaning")])
    described_class.new(path:).call

    expect(lexeme.reload.meaning(:en)).to(eq("changed meaning"))
    expect(memory.reload.stability).to(eq(12.0))
    expect(memory.state).to(eq("review"))
  end

  it "never deletes a lexeme or a memory when an entry leaves the source" do
    write([base("測試甲"), base("測試乙")])
    described_class.new(path:).call
    dropped = Lexeme.find_by!(text: "測試乙")
    memory = LexemeMemory.create!(user:, lexeme: dropped, facet: "recognition", activated_at: Time.current)

    write([base("測試甲")])
    described_class.new(path:).call

    expect(Lexeme.exists?(dropped.id)).to(be(true))
    expect(LexemeMemory.exists?(memory.id)).to(be(true))
  end

  it "refuses to prune when the source shrinks implausibly" do
    write(Array.new(20) { |i| base("測試#{i}") })
    described_class.new(path:).call
    collection = Collection.find_by!(kind: :everyday)
    expect(collection.collection_items.count).to(eq(20))

    write([base("測試0")])
    result = described_class.new(path:).call

    expect(result.dropped).to(eq(0))
    expect(collection.collection_items.count).to(eq(20))
  end

  it "unlists an entry the source dropped when the change is small" do
    write(Array.new(20) { |i| base("測試#{i}") })
    described_class.new(path:).call
    collection = Collection.find_by!(kind: :everyday)

    write(Array.new(19) { |i| base("測試#{i}") })
    result = described_class.new(path:).call

    expect(result.dropped).to(eq(1))
    expect(collection.collection_items.count).to(eq(19))
    expect(Lexeme.exists?(text: "測試19")).to(be(true))
  end

  it "skips malformed entries instead of failing the whole import" do
    write([base("測試甲"), {"text" => "壞", "pinyin" => "huài"}])

    result = described_class.new(path:).call

    expect(result.imported).to(eq(1))
    expect(result.skipped).to(eq(1))
  end
end
