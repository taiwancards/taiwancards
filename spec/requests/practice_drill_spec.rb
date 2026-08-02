# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Phonetics drill" do
  SYLLABLES = {
    "中" => %w[zhōng ㄓㄨㄥ],
    "九" => %w[jiǔ ㄐㄧㄡˇ],
    "回" => %w[huí ㄏㄨㄟˊ],
    "雨" => %w[yǔ ㄩˇ],
    "知" => %w[zhī ㄓ],
    "我" => %w[wǒ ㄨㄛˇ],
    "他" => %w[tā ㄊㄚ],
    "馬" => %w[mǎ ㄇㄚˇ],
    "大" => %w[dà ㄉㄚˋ],
    "好" => %w[hǎo ㄏㄠˇ],
    "book" => %w[shū ㄕㄨ],
    "來" => %w[lái ㄌㄞˊ]
  }.freeze

  def seed_syllables!
    SYLLABLES.each_with_index do |(text, (pinyin, zhuyin)), index|
      create(
        :lexeme,
        kind: :character,
        text: text == "book" ? "書" : text,
        readings: {"pinyin" => pinyin, "zhuyin" => zhuyin},
        meanings: {"en" => "gloss"},
        data: {"freq_rank" => index + 1}
      )
    end
  end

  it "serves every stage with four-way options" do
    seed_syllables!
    sign_in(create(:user))

    get(practice_drill_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("practice.drill.title")))

    node = Nokogiri::HTML(response.body).at("[data-phonetics-drill-items-value]")
    items = JSON.parse(node["data-phonetics-drill-items-value"])

    expect(items.keys).to(match_array(Huayu::PhoneticsDrill::STAGES))
    Huayu::PhoneticsDrill::STAGES.each do |stage|
      expect(items[stage]).to(be_present, "expected items for #{stage}")
      expect(items[stage]).to(all(include("zhuyin", "pinyin", "id", "distractors")))
      items[stage].each do |row|
        expect(row["distractors"].size)
          .to(be_between(Huayu::PhoneticsDrill::CHOICES - 1, Huayu::PhoneticsDrill::CANDIDATES))
      end
    end
  end

  it "keeps every option of a syllable item on the same tone" do
    seed_syllables!
    drill = Huayu::PhoneticsDrill.new(locale: :en)

    drill.items("syllables").each do |item|
      tone = Huayu::Zhuyin.tone(item[:pinyin])
      item[:distractors].each do |distractor|
        expect(Huayu::Zhuyin.tone(distractor[:pinyin])).to(eq(tone), "#{item[:pinyin]} vs #{distractor[:pinyin]}")
      end
    end
  end

  it "prefers confusable syllables as distractors" do
    seed_syllables!
    drill = Huayu::PhoneticsDrill.new(locale: :en)

    ta = drill.items("syllables").find { |row| row[:pinyin] == "tā" }
    expect(ta[:distractors].map { |d| d[:zhuyin] }).to(include("ㄉㄚ", "ㄇㄚ"))
  end

  it "collapses tone variants of one syllable into a single item" do
    seed_syllables!
    create(
      :lexeme,
      kind: :character,
      text: "罵",
      readings: {"pinyin" => "mà", "zhuyin" => "ㄇㄚˋ"},
      meanings: {"en" => "scold"},
      data: {"freq_rank" => 99}
    )
    drill = Huayu::PhoneticsDrill.new(locale: :en)

    bares = drill.items("syllables").map { |row| row[:zhuyin].delete(Huayu::ReadingForms::ZHUYIN_TONES) }
    expect(bares.count("ㄇㄚ")).to(eq(1))
  end

  it "never offers a distractor equal to the answer" do
    seed_syllables!
    drill = Huayu::PhoneticsDrill.new(locale: :en)

    Huayu::PhoneticsDrill::STAGES.each do |stage|
      drill.items(stage).each do |item|
        expect(item[:distractors].map { |d| d[:zhuyin] }).not_to(include(item[:zhuyin]))
      end
    end
  end

  it "puts the cases where pinyin hides the structure ahead of the plain ones" do
    seed_syllables!
    drill = Huayu::PhoneticsDrill.new(locale: :en)

    rows = drill.items("syllables")
    hard_positions = rows.each_index.select { |i| rows[i][:hard] }
    plain_positions = rows.each_index.reject { |i| rows[i][:hard] }

    expect(hard_positions).to(be_present)
    expect(plain_positions).to(be_present)
    expect(hard_positions.max).to(be < plain_positions.min)
  end

  it "recognises the syllables where pinyin spelling hides the real rime" do
    seed_syllables!
    drill = Huayu::PhoneticsDrill.new(locale: :en)

    found = drill.items("syllables").to_h { |row| [row[:pinyin], row[:hard]] }

    expect(found["zhōng"]).to(eq("ong"))
    expect(found["jiǔ"]).to(eq("iu"))
    expect(found["huí"]).to(eq("ui"))
    expect(found["zhī"]).to(eq("empty"))
    expect(found["yǔ"]).to(eq("glide"))
    expect(found["tā"]).to(be_nil)
  end

  it "drills consonants without the pinyin-only glides y and w" do
    drill = Huayu::PhoneticsDrill.new(locale: :en)

    expect(drill.items("consonants").map { |row| row[:pinyin] }).not_to(include("y", "w"))
  end

  it "remembers the sounds you missed and accumulates them" do
    user = sign_in(create(:user))

    post(practice_drill_path, params: {misses: {"initial:b" => 2, "final:a" => 1}})
    expect(response).to(have_http_status(:no_content))
    expect(user.reload.phonetic_misses).to(eq({"initial:b" => 2, "final:a" => 1}))

    post(practice_drill_path, params: {misses: {"initial:b" => 1}})
    expect(user.reload.phonetic_misses).to(eq({"initial:b" => 3, "final:a" => 1}))
  end

  it "ignores a result with nothing missed" do
    user = sign_in(create(:user))

    post(practice_drill_path, params: {})

    expect(response).to(have_http_status(:no_content))
    expect(user.reload.phonetic_misses).to(be_empty)
  end

  it "offers the drill on the practice index" do
    sign_in(create(:user))

    get(practice_path)

    expect(response.body).to(include(practice_drill_path))
  end

  it "is closed to visitors who are not signed in", :no_auth do
    get(practice_drill_path)

    expect(response).to(redirect_to(login_path))
  end
end
