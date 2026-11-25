# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ConcisedSenseRepair do
  let(:source) do
    ContentSource.create!(
      slug: "moe_concised",
      license_commercial: true,
      name: "MOE",
      attribution: "MOE.",
      enabled: true,
      enabled_for_admins: true
    )
  end

  let(:synonyms) { Rails.root.join("tmp/spec-concised-synonyms.json") }
  let(:rejects) { Rails.root.join("tmp/spec-concised-rejects.jsonl") }

  before do
    synonyms.write(JSON.generate({"芒果" => ["檬果"]}))
    rejects.write(
      [
        {text: "他常常無故發牌氣，真叫人受不了！", reason: "garbled"},
        {text: "這小孩子很叫人。", reason: "fragment"}
      ].map { |row| JSON.generate(row) }.join("\n")
    )
    allow(described_class::SYNONYMS).to(receive(:path).and_return(synonyms))
    described_class::SYNONYMS.reset!
    stub_const("#{Huayu::SentenceRejectStore}::PATH", rejects)
  end

  after do
    described_class::SYNONYMS.reset!
    [synonyms, rejects].each { |path| path.delete if path.exist? }
  end

  def sense(word, gloss, examples: [], position: 0)
    lexeme = Lexeme.find_by(kind: :word, text: word) || create(:lexeme, kind: :word, text: word)
    sense = lexeme.senses.create!(position:, gloss_zh: gloss, content_source: source)
    examples.each_with_index do |(kind, text), index|
      sense.examples.create!(kind:, text:, position: index, content_source: source)
    end

    sense
  end

  def texts(sense) = sense.examples.reload.map(&:text)

  it "drops the Ministry numbering and the similar words from a definition" do
    numbered = sense("母親", "2.比喻孕育的根源。")
    marked = sense("切", "古代拼音法。　△反切", position: 1)

    described_class.new.call

    expect(numbered.reload.gloss_zh).to(eq("比喻孕育的根源。"))
    expect(marked.reload.gloss_zh).to(eq("古代拼音法。"))
  end

  it "keeps the numbering where it is the only thing telling two readings' senses apart" do
    first = sense("削", "刪減。")
    second = sense("削", "2.刪減。", position: 1)

    described_class.new.call

    expect([first.reload.gloss_zh, second.reload.gloss_zh]).to(eq(%w[刪減。 2.刪減。]))
    expect(described_class.new.drift?).to(be(false))
  end

  it "removes an example the dictionary filed under a word it does not contain" do
    record = sense(
      "呀",
      "助詞。",
      examples: [[:sentence, "他呀！"], [:sentence, "恐怕無法來參加這次的聚會。"]]
    )

    expect(described_class.new.call.misfiled).to(eq(1))
    expect(texts(record)).to(eq(["他呀！"]))
  end

  it "trims the similar word off a collocation and drops it where the sense already has the bare one" do
    record = sense(
      "刷",
      "用來清除異物的器具。",
      examples: [
        [:collocation, "牙刷"],
        [:collocation, "油漆刷　△刷子"],
        [:collocation, "牙刷　△刷子"],
        [:sentence, "刷牙刷得很乾淨　△牙刷子"]
      ]
    )

    described_class.new.call

    expect(texts(record)).to(eq(%w[牙刷 油漆刷 刷牙刷得很乾淨]))
  end

  it "removes synonym lists and the similar words the dictionary lists for the headword" do
    aunt = sense(
      "姑姑",
      "稱父親的姊妹。",
      examples: [[:sentence, "姑姑家很遠。"], [:collocation, "姑媽、姑母"]]
    )
    mango = sense("芒果", "植物名。", examples: [[:collocation, "芒果乾"], [:collocation, "檬果"]])
    gas = sense("天然氣", "可燃性氣體。", examples: [[:sentence, "天然煤氣、天然瓦斯"]])

    described_class.new.call

    expect(texts(aunt)).to(eq(["姑姑家很遠。"]))
    expect(texts(mango)).to(eq(["芒果乾"]))
    expect(texts(gas)).to(be_empty)
  end

  it "removes an example the reviewers judged garbled and keeps one they only found fragmentary" do
    record = sense(
      "叫",
      "使、令。",
      examples: [
        [:sentence, "他常常無故發牌氣，真叫人受不了！"],
        [:sentence, "這小孩子很叫人。"]
      ]
    )

    expect(described_class.new.call.rejected).to(eq(1))
    expect(texts(record)).to(eq(["這小孩子很叫人。"]))
  end

  it "reports no drift once everything is clean" do
    sense("呀", "2.助詞。", examples: [[:sentence, "他呀！"], [:sentence, "車子來了。"]])

    repair = described_class.new
    expect(repair.drift?).to(be(true))
    repair.call

    expect(described_class.new.drift?).to(be(false))
  end

  it "changes nothing on a dry run" do
    record = sense("呀", "2.助詞。", examples: [[:sentence, "車子來了。"]])

    result = described_class.new.call(dry_run: true)

    expect(result.changed?).to(be(true))
    expect(record.reload.gloss_zh).to(eq("2.助詞。"))
    expect(texts(record)).to(eq(["車子來了。"]))
  end
end
