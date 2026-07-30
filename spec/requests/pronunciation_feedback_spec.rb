# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pronunciation feedback", :aggregate_failures do
  let(:data_path) { Rails.root.join("data/pronunciation") }

  before do
    skip("data/pronunciation not checked out") unless File.directory?(data_path.join("templates/taiwan"))

    ENV["PRONUNCIATION_DATA_PATH"] = data_path.to_s
    Pronunciation::TemplateStore.reset!
    Pronunciation::Drills.reset!
    Pronunciation::Acoustic::Syllables.load!
  end

  after do
    ENV.delete("PRONUNCIATION_DATA_PATH")
    Pronunciation::TemplateStore.reset!
    Pronunciation::Drills.reset!
  end

  def synthetic_wav(ms: 420, rate: 16_000)
    samples = (ms * rate / 1000).to_i
    phase = 0.0
    body = (0...samples).map { |i|
      t = i.to_f / rate
      f0 = 125.0 * (2 ** ((-2.0 * t / (ms / 1000.0)) / 12))
      phase += 2 * Math::PI * f0 / rate
      value = [[1, 1.0], [2, 0.6], [3, 0.4], [5, 0.5], [7, 0.35], [11, 0.2]].sum { |(harmonic, amp)|
        amp * Math.sin(phase * harmonic)
      }
      envelope = [1.0, t / 0.03, ((ms / 1000.0) - t) / 0.05].min
      [(value * envelope * 0.09 * 32_767).to_i, 32_767].min.clamp(-32_767, 32_767)
    }

    header = "RIFF" +
      [36 + (body.length * 2)].pack("V") +
      "WAVEfmt " +
      [16, 1, 1, rate, rate * 2, 2, 16].pack("VvvVVvv") +
      "data" +
      [body.length * 2].pack("V")
    (header + body.pack("s<*")).b
  end

  def grade(key:, zhuyin:, tone:, char: "馬")
    Pronunciation::AcousticBackend
      .new(locale: :ru)
      .grade(
        audio: synthetic_wav,
        text: char,
        syllables: [{"char" => char, "pinyin" => key, "tone" => tone, "key" => key, "zhuyin" => zhuyin}]
      )
  end

  it "describes every part of the syllable, not just a single number" do
    result = grade(key: "ma3", zhuyin: "ㄇㄚˇ", tone: 3)
    syllable = result["syllables"].first

    expect(syllable["parts"].map { |p| p["id"] }).to(eq(%w[initial medial final tone]))
    expect(syllable["parts"].map { |p| p["level"] }).to(all(be_in(%w[green amber red dark gray none])))
    expect(syllable["parts"].sum { |p| p["weight"] }).to(be_within(2).of(100))
  end

  it "returns both curves so the learner can see where the tone went wrong" do
    contour = grade(key: "ma3", zhuyin: "ㄇㄚˇ", tone: 3)["syllables"].first["contour"]

    expect(contour["curve"].length).to(eq(Pronunciation::Acoustic::Features::TONE_POINTS))
    expect(contour["reference"].length).to(eq(contour["curve"].length))
    expect(contour["sigma"].length).to(eq(contour["curve"].length))
  end

  it "labels the parts in zhuyin with their IPA" do
    parts = grade(key: "qi1", zhuyin: "ㄑㄧ", tone: 1)["syllables"].first["parts"]
    initial = parts.find { |p| p["id"] == "initial" }

    expect(initial).to(include("zhuyin" => "ㄑ", "pinyin" => "q", "ipa" => "tɕʰ"))
    expect(initial["cue"]).to(be_present)
  end

  it "admits when a part cannot be measured instead of inventing a score" do
    initial = grade(key: "ma3", zhuyin: "ㄇㄚˇ", tone: 3)["syllables"].first["parts"].first

    expect(initial).to(include("id" => "initial", "measured" => false, "level" => "gray", "weight" => 0))
    expect(initial).not_to(have_key("problem"))
  end

  it "carries the four-level legend so the colors can be explained in place" do
    legend = grade(key: "ma3", zhuyin: "ㄇㄚˇ", tone: 3)["legend"]

    expect(legend.map { |row| row["level"] }).to(eq(%w[green amber red dark]))
    expect(legend.map { |row| row["name"] }).to(all(be_present))
    expect(legend.map { |row| row["note"] }).to(all(be_present))
  end

  it "hands the recorder everything it needs to accumulate a skill row" do
    user = create(:user)
    lexeme = create(:lexeme, kind: :word, text: "馬", readings: {"pinyin" => "mǎ"})
    result = grade(key: "ma3", zhuyin: "ㄇㄚˇ", tone: 3)

    Pronunciation::SkillRecorder.new(user, lexeme).call(result["syllables"])

    skill = SyllableSkill.find_by(user:, syllable_key: "ma3")
    expect(skill).to(have_attributes(n: 1, syllable: "ma", tone: 3))
    expect(skill.ewma_overall).to(be_present)
    expect(skill.z_n.sum).to(be_positive)
  end
end
