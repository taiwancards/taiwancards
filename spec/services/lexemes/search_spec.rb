# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::Search do
  def word(text, pinyin, zhuyin, score:, meaning: "meaning", kind: :word)
    create(
      :lexeme,
      kind:,
      text:,
      score:,
      readings: {"pinyin" => pinyin, "zhuyin" => zhuyin},
      meanings: {"en" => meaning},
      data: {"readings" => [{"pinyin" => pinyin, "zhuyin" => zhuyin}]}
    )
  end

  def texts(query)
    described_class.new.call(query).results.map { |result| result.lexeme.text }
  end

  describe "tones" do
    before do
      word("是", "shì", "ㄕˋ", score: 1, kind: :character, meaning: "to be")
      word("十", "shí", "ㄕˊ", score: 2, kind: :character, meaning: "ten")
      word("使", "shǐ", "ㄕˇ", score: 80, kind: :character, meaning: "to make")
    end

    it "puts the asked-for tone first even when another tone is far more frequent" do
      expect(texts("shi2").first).to(eq("十"))
      expect(texts("shi3").first).to(eq("使"))
    end

    it "keeps the other tones, only lower down" do
      expect(texts("shi3")).to(include("是", "十"))
      expect(texts("shi3").index("使")).to(be < texts("shi3").index("是"))
    end

    it "falls back to frequency when no tone is given" do
      expect(texts("shi")).to(eq(%w[是 十 使]))
    end

    it "reads the tone from zhuyin the same way as from a digit" do
      expect(texts("ㄕˊ").first).to(eq("十"))
      expect(texts("ㄕ")).to(eq(%w[是 十 使]))
    end

    it "reads the tone from a diacritic the same way as from a digit" do
      expect(texts("shí").first).to(eq("十"))
    end

    it "honors the tones it was given when only some carry a digit" do
      word("十分", "shífēn", "ㄕˊ ㄈㄣ", score: 30)
      word("時分", "shífēn", "ㄕˊ ㄈㄣ", score: 400)
      word("市分", "shìfēn", "ㄕˋ ㄈㄣ", score: 5)

      expect(texts("shi2fen").first).to(eq("十分"))
    end
  end

  describe "spellings" do
    before { word("學校", "xuéxiào", "ㄒㄩㄝˊ ㄒㄧㄠˋ", score: 5, meaning: "school") }

    it "finds the same word however the reading is written" do
      [
        "xuéxiào",
        "xué xiào",
        "xue2xiao4",
        "xue2 xiao4",
        "xuexiao",
        "xue xiao",
        "ㄒㄩㄝˊㄒㄧㄠˋ",
        "ㄒㄩㄝㄒㄧㄠ"
      ].each do |query|
        expect(texts(query)).to(include("學校"))
      end
    end

    it "finds it by hanzi and by meaning too" do
      expect(texts("學校")).to(include("學校"))
      expect(texts("school")).to(include("學校"))
    end
  end

  describe "what the quick panel returns" do
    before do
      15.times { |index| word("詞#{index}", "cí", "ㄘˊ", score: index + 1, meaning: "word #{index}") }
      source = ContentSource.find_by(slug: "corpus") ||
        ContentSource.create!(
          slug: "corpus",
          license_commercial: true,
          name: "Corpus",
          register: :colloquial,
          enabled: true,
          enabled_for_admins: true,
          attribution: "Corpus."
        )
      create(:lexeme, kind: :sentence, text: "我去學校。", score: 1, content_sources: [source])
    end

    it "never returns more than ten rows and says when it held some back" do
      page = described_class.new.call("ci")

      expect(page.results.length).to(eq(10))
      expect(page.truncated).to(be(true))
    end

    it "leaves sentences out" do
      expect(texts("我去學校。")).not_to(include("我去學校。"))
    end

    it "returns nothing for a blank query" do
      expect(described_class.new.call("  ").results).to(be_empty)
    end
  end

  describe "readings that the data stores awkwardly" do
    it "finds a word whose zhuyin syllables are split by a full-width space" do
      create(
        :lexeme,
        kind: :word,
        text: "我們",
        score: 3,
        readings: {"pinyin" => "wǒmen", "zhuyin" => "ㄨㄛˇ　˙ㄇㄣ"},
        meanings: {"en" => "we"},
        data: {"readings" => [{"pinyin" => "wǒmen", "zhuyin" => "ㄨㄛˇ　˙ㄇㄣ"}]}
      )

      ["ㄨㄛˇ˙ㄇㄣ", "ㄨㄛˇ　˙ㄇㄣ", "ㄨㄛㄇㄣ", "wo3men5", "women"].each do |query|
        expect(texts(query)).to(include("我們"), "expected #{query} to find 我們")
      end
    end

    it "does not let a meaning drown out a one-syllable reading" do
      word("啊", "a", "ㄚ", score: 90, kind: :character, meaning: "ah")
      10.times { |index| word("詞#{index}", "cí", "ㄘˊ", score: index + 1, meaning: "a thing number #{index}") }

      expect(texts("ㄚ")).to(include("啊"))
      expect(texts("a")).to(include("啊"))
    end
  end

  describe "words borrowed from Taiwanese Hokkien" do
    it "finds a word by the way Taiwanese Hokkien says it, not by its characters" do
      create(
        :lexeme,
        kind: :word,
        text: "歹勢",
        score: 40,
        readings: {"pinyin" => "dǎishì", "zhuyin" => "ㄉㄞˇ ㄕˋ"},
        meanings: {"en" => "sorry"},
        data: {
          "readings" => [{"pinyin" => "dǎishì", "zhuyin" => "ㄉㄞˇ ㄕˋ"}],
          "hokkien" => {
            "tailo" => "pháinn-sè",
            "reading" => "native",
            "say" => {"zhuyin" => "ㄆㄞˋ ㄙㄝˋ", "pinyin" => "pài sè"}
          }
        }
      )

      [
        "paise",
        "pài sè",
        "pai4se4",
        "ㄆㄞˋㄙㄝˋ",
        "ㄆㄞㄙㄝ",
        "pháinn-sè",
        "phainn-se",
        "phainnse",
        "dǎishì"
      ].each do |query|
        expect(texts(query)).to(include("歹勢"), "expected #{query} to find 歹勢")
      end
    end

    it "finds a word whose Hokkien sound is not a Mandarin syllable at all" do
      create(
        :lexeme,
        kind: :word,
        text: "囝仔",
        score: 60,
        readings: {"pinyin" => "jiǎnzǐ", "zhuyin" => "ㄐㄧㄢˇ ㄗˇ"},
        meanings: {"en" => "child"},
        data: {
          "readings" => [{"pinyin" => "jiǎnzǐ", "zhuyin" => "ㄐㄧㄢˇ ㄗˇ"}],
          "hokkien" => {
            "tailo" => "gín-á",
            "reading" => "native",
            "say" => {"zhuyin" => "ㄍㄧㄣˇ ㄚˋ", "pinyin" => "gǐn à"}
          }
        }
      )

      ["gina", "gǐn à", "gin-a", "gín-á"].each do |query|
        expect(texts(query)).to(include("囝仔"), "expected #{query} to find 囝仔")
      end
    end

    it "keeps a Hokkien sound below a word that really reads that way in Mandarin" do
      create(
        :lexeme,
        kind: :word,
        text: "派色",
        score: 5,
        readings: {"pinyin" => "pàisè", "zhuyin" => "ㄆㄞˋ ㄙㄝˋ"},
        meanings: {"en" => "a made-up test word"},
        data: {"readings" => [{"pinyin" => "pàisè", "zhuyin" => "ㄆㄞˋ ㄙㄝˋ"}]}
      )
      create(
        :lexeme,
        kind: :word,
        text: "歹勢",
        score: 1,
        readings: {"pinyin" => "dǎishì", "zhuyin" => "ㄉㄞˇ ㄕˋ"},
        meanings: {"en" => "sorry"},
        data: {
          "readings" => [{"pinyin" => "dǎishì", "zhuyin" => "ㄉㄞˇ ㄕˋ"}],
          "hokkien" => {
            "tailo" => "pháinn-sè",
            "reading" => "native",
            "say" => {"zhuyin" => "ㄆㄞˋ ㄙㄝˋ", "pinyin" => "pài sè"}
          }
        }
      )

      expect(texts("paise").index("派色")).to(be < texts("paise").index("歹勢"))
    end
  end
end
