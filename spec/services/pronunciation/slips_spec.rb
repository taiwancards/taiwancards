# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Slips do
  def slips(expected, heard) = described_class.between(*expected, *heard)

  it "names a drifted initial in zhuyin and pinyin" do
    expect(slips(%w[fen3 ㄈㄣˇ], %w[hen3 ㄏㄣˇ]))
      .to(eq([{"part" => "initial", "zhuyin" => "ㄈ→ㄏ", "pinyin" => "f→h"}]))
  end

  it "spells a changed final as whole pinyin syllables, since pinyin rimes depend on the syllable" do
    expect(slips(%w[wen2 ㄨㄣˊ], %w[yun2 ㄩㄣˊ]))
      .to(eq([{"part" => "medial", "zhuyin" => "ㄨ→ㄩ", "pinyin" => "wen→yun"}]))
    expect(slips(%w[fen1 ㄈㄣ], %w[feng1 ㄈㄥ]))
      .to(eq([{"part" => "final", "zhuyin" => "ㄣ→ㄥ", "pinyin" => "fen→feng"}]))
  end

  it "keeps ü apart from u" do
    expect(slips(%w[lu4 ㄌㄩˋ], %w[lu4 ㄌㄨˋ]).first["pinyin"]).to(eq("lü→lu"))
  end

  it "marks tones with zhuyin tone marks and numbers" do
    expect(slips(%w[hao3 ㄏㄠˇ], %w[hao2 ㄏㄠˊ]))
      .to(eq([{"part" => "tone", "zhuyin" => "ˇ→ˊ", "pinyin" => "3→2"}]))
  end

  it "shows a missing sound as an empty set rather than dropping it" do
    expect(slips(%w[an4 ㄢˋ], %w[han4 ㄏㄢˋ]).first["zhuyin"]).to(eq("∅→ㄏ"))
    expect(slips(%w[zhi1 ㄓ], %w[zhe1 ㄓㄜ]).first["zhuyin"]).to(eq("∅→ㄜ"))
  end

  it "returns nothing it cannot read" do
    expect(slips(["", ""], %w[hao2 ㄏㄠˊ])).to(eq([]))
  end
end
