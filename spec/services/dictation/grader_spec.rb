# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictation::Grader do
  subject(:grader) { described_class.new("我也不知道") }

  before do
    source = ContentSource.create!(
      slug: "voices",
      license_commercial: true,
      name: "Voices",
      enabled: true,
      enabled_for_admins: true,
      attribution: "Voices."
    )
    sentence = Lexeme.new(
      kind: :sentence,
      text: "我也不知道",
      readings: {"pinyin" => "wǒ yě bù zhīdào", "zhuyin" => "ㄨㄛˇ ㄧㄝˇ ㄅㄨˋ ㄓ ㄉㄠˋ"},
      data: {"segments" => %w[我 也 不 知道]}
    )
    sentence.lexeme_content_sources.build(content_source: source)
    sentence.save!
    create(:lexeme, kind: :character, text: "到", readings: {"pinyin" => "dào", "zhuyin" => "ㄉㄠˋ"})
  end

  def marks(answer) = grader.call(answer).cells.map(&:mark)

  it "gives full marks to characters, toned pinyin and toned zhuyin alike" do
    ["我也不知道", "wo3 ye3 bu4 zhi1 dao4", "ㄨㄛˇ ㄧㄝˇ ㄅㄨˋ ㄓ ㄉㄠˋ"].each do |answer|
      expect(grader.call(answer).percent).to(eq(100), answer)
    end
  end

  it "accepts the tone heard in speech as well as the dictionary tone" do
    expect(marks("wo2 ye3 bu4 zhi1 dao4").first).to(eq(:exact))
  end

  it "takes a quarter off a syllable without a tone and half off a wrong tone" do
    expect(grader.call("wo ye bu zhi dao").percent).to(eq(75))
    expect(marks("wo4 ye3 bu4 zhi1 dao4").first).to(eq(:wrong_tone))
    expect(grader.call("wo4 ye3 bu4 zhi1 dao4").percent).to(eq(90))
  end

  it "gives half for another character with the same sound" do
    result = grader.call("我也不知到")

    expect(result.cells.last.mark).to(eq(:sound))
    expect(result.cells.last.typed).to(eq("到"))
    expect(result.percent).to(eq(90))
  end

  it "marks what was left out and counts extra syllables against the score" do
    expect(marks("我也")).to(eq([:exact, :exact, nil, nil, nil]))
    expect(grader.call("我也不知道我也").percent).to(eq(71))
    expect(grader.call("我也不知道我也").extra).to(eq(2))
  end

  it "scores an empty answer as nothing heard" do
    expect(grader.call("").percent).to(eq(0))
  end
end
