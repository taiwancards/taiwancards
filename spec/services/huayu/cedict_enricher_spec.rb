# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::CedictEnricher do
  let(:dir) { Pathname(Dir.mktmpdir) }

  let(:path) do
    file = dir.join("cedict.json")
    file.write(
      {
        "嘴唇" => {"pinyin" => "zuǐ chún", "glosses" => %w[lip]},
        "學生" => {"pinyin" => "xué shēng", "glosses" => ["student", "pupil"]}
      }.to_json
    )
    file
  end

  after { dir.rmtree }

  def run = described_class.new(path: path).call

  it "fills a reading that is missing altogether" do
    lexeme = create(:lexeme, kind: :word, text: "學生", readings: {})

    run

    expect(lexeme.reload.readings["pinyin"]).to(eq("xué shēng"))
    expect(lexeme.readings["zhuyin"]).to(be_present)
  end

  it "repairs a reading that has lost a syllable" do
    lexeme = create(:lexeme, kind: :word, text: "嘴唇", readings: {"pinyin" => "chún", "zhuyin" => "ㄔㄨㄣˊ"})

    expect(run).to(include(repaired: 1))
    expect(lexeme.reload.readings["pinyin"]).to(eq("zuǐ chún"))
    expect(lexeme.readings["zhuyin"]).to(eq("ㄗㄨㄟˇ ㄔㄨㄣˊ"))
  end

  it "leaves a sound reading alone even when CC-CEDICT disagrees" do
    lexeme = create(
      :lexeme,
      kind: :word,
      text: "學生",
      readings: {"pinyin" => "xué sheng", "zhuyin" => "ㄒㄩㄝˊ ˙ㄕㄥ"}
    )

    run

    expect(lexeme.reload.readings["zhuyin"]).to(eq("ㄒㄩㄝˊ ˙ㄕㄥ"))
  end

  it "fills an English gloss the dictionary has and we lack" do
    lexeme = create(:lexeme, kind: :word, text: "學生", readings: {}, meanings: {})

    run

    expect(lexeme.reload.meanings["en"]).to(eq("student; pupil"))
  end
end
