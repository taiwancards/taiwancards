# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Calibration do
  it "walks the same seven steps in every language" do
    %w[en ru vi].each do |locale|
      prompts = described_class.prompts_for(locale)

      expect(prompts.pluck(:id)).to(eq(%w[vowels rise fall tone_1 tone_2 tone_3 tone_4]))
      expect(prompts.pluck(:kind)).to(eq(%i[sustained intonation intonation tone tone tone tone]))
      expect(prompts.last(4).pluck(:text)).to(eq(%w[媽 麻 馬 罵]))
      expect(prompts.last(4).pluck(:tone)).to(eq([1, 2, 3, 4]))
      expect(prompts.first(3)).to(all(satisfy { |prompt| !prompt.key?(:tone) }))
      expect(prompts.pluck(:hint)).to(all(be_present))
    end
  end

  it "keeps the English and Russian wording" do
    expect(described_class.prompts_for("en").first).to(
      eq(
        {
          id: "vowels",
          text: "ee — ah — oo",
          hint: "hold each sound for about a second and a half",
          kind: :sustained
        }
      )
    )
    expect(described_class.prompts_for("ru")[4][:hint]).to(
      eq(
        "снизу вверх, как переспрос «Да?» — голос идёт вверх и не останавливается"
      )
    )
  end

  it "speaks Vietnamese to Vietnamese learners instead of falling back to English" do
    prompts = described_class.prompts_for("vi")

    expect(prompts.first[:text]).to(eq("i — a — u"))
    expect(prompts[1][:text]).to(eq("Thật à?!"))
    expect(prompts.last[:hint]).to(eq("rơi mạnh từ cao xuống thấp, như khi quát “Dừng lại!”"))
  end

  it "falls back to English for a language it does not speak" do
    expect(described_class.prompts_for("ja-JP")).to(eq(described_class.prompts_for("en")))
    expect(described_class.prompts_for("ru-RU")).to(eq(described_class.prompts_for("ru")))
  end
end
