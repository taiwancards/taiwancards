# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Focus do
  let(:user) { create(:user) }

  KEYS = {
    "qi1" => "ㄑㄧ",
    "qu4" => "ㄑㄩ",
    "qian2" => "ㄑㄧㄢ",
    "gao1" => "ㄍㄠ",
    "ma3" => "ㄇㄚ"
  }.freeze

  before do
    @dir = Dir.mktmpdir
    keys = KEYS.to_h { |key, zhuyin|
      [key, {"syllable" => key[0..-2], "tone" => key[-1].to_i, "zhuyin" => zhuyin}]
    }
    File.write(File.join(@dir, "inventory.json"), JSON.dump({"keys" => keys}))
    Pronunciation::Acoustic::Syllables.load!(File.join(@dir, "inventory.json"))
  end

  after do
    FileUtils.remove_entry(@dir)
    Pronunciation::Acoustic::Syllables.load!
  end

  let(:drills) do
    instance_double(
      Pronunciation::Drills,
      section: nil
    )
      .tap do |double|
        allow(double).to(receive(:section)) { |id| {"id" => id} if %w[aspiration tone_3 vowel_i].include?(id) }
      end
  end

  def focus_for(user, locale: :en)
    described_class.new(user, locale:, drills:)
  end

  def practice(key, times:, initial: 90, final: 90, tone: 90, codes: [], deviations: {})
    times.times do
      SyllableSkill.claim(user, key).record!(
        overall: [initial, final, tone].sum / 3,
        level: "amber",
        parts: {"initial" => initial, "final" => final, "tone" => tone},
        codes:,
        deviations:
      )
    end
  end

  it "names the phoneme behind several weak syllables" do
    %w[qi1 qu4 qian2].each do |key|
      practice(key, times: 6, initial: 45, codes: ["initial.under_aspirated"], deviations: {"vot_ms" => -2.1})
    end

    practice("gao1", times: 6)

    top = focus_for(user, locale: :ru).weaknesses.first
    expect(top).to(include("part" => "initial", "zhuyin" => "ㄑ"))
    expect(top["n"]).to(eq(18))
    expect(top["keys"]).to(match_array(%w[qi1 qu4 qian2]))
  end

  it "reports the systematic direction of the error, not just its size" do
    %w[qi1 qu4].each do |key|
      practice(key, times: 6, initial: 45, codes: ["initial.under_aspirated"], deviations: {"vot_ms" => -2.1})
    end

    top = focus_for(user, locale: :ru).weaknesses.first
    expect(top["bias"].first).to(include("field" => "vot_ms"))
    expect(top["bias"].first["z"]).to(be < -1)
  end

  it "routes the weakness to a drill that actually contains it" do
    %w[qi1 qu4].each do |key|
      practice(key, times: 6, initial: 45, codes: ["initial.under_aspirated"])
    end

    expect(focus_for(user).weaknesses.first["section"]).to(eq("aspiration"))
  end

  it "ranks by urgency, so a common weakness outranks a rarer worse one" do
    bounds = Pronunciation::Verdict.new
    initial_gap = 15
    tone_gap = 25
    %w[qi1 qu4 qian2].each { |key| practice(key, times: 8, initial: bounds.bounds("initial")["green"] - initial_gap) }
    practice("ma3", times: 4, tone: bounds.bounds("tone")["green"] - tone_gap)

    parts = focus_for(user).weaknesses.map { |row| row["part"] }
    expect(parts.first).to(eq("initial"))
  end

  it "says nothing about a phoneme it has barely heard" do
    practice("qi1", times: 1, initial: 10)

    expect(focus_for(user).weaknesses).to(be_empty)
  end

  it "leaves other learners out of it" do
    practice("qi1", times: 8, initial: 30)

    expect(focus_for(create(:user)).weaknesses).to(be_empty)
    expect(focus_for(create(:user)).summary).to(be_nil)
  end

  it "summarises the whole practice history from the accumulators" do
    practice("qi1", times: 10, initial: 45)
    practice("gao1", times: 5)

    expect(focus_for(user).summary).to(include("syllables" => 2, "attempts" => 15))
  end
end
