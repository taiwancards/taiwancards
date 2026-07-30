# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Corpus search" do
  let!(:source) do
    ContentSource.find_by(slug: "corpus") ||
      ContentSource.create!(
        slug: "corpus",
        license_commercial: true,
        name: "Corpus",
        register: :colloquial,
        enabled: true,
        enabled_for_admins: true,
        attribution: "Corpus."
      )
  end

  def word(text, pinyin, zhuyin, score:, meaning: "meaning", kind: :word, data: {})
    create(
      :lexeme,
      kind:,
      text:,
      score:,
      readings: {"pinyin" => pinyin, "zhuyin" => zhuyin},
      meanings: {"en" => meaning},
      data: data.merge("readings" => [{"pinyin" => pinyin, "zhuyin" => zhuyin}])
    )
  end

  def sentence(text, segments, meaning: nil, difficulty: 5, registers: [0])
    lexeme = create(
      :lexeme,
      kind: :sentence,
      text:,
      score: difficulty,
      meanings: meaning ? {"en" => meaning} : {},
      data: {"segments" => segments, "difficulty" => difficulty},
      content_sources: [source]
    )
    SentenceProfile.create!(
      lexeme:,
      difficulty:,
      registers:,
      source_ids: [source.id],
      tocfl_index: 3,
      han_length: text.scan(/\p{Han}/).length
    )
    lexeme
  end

  let!(:xuexiao) { word("學校", "xuéxiào", "ㄒㄩㄝˊ ㄒㄧㄠˋ", score: 5, meaning: "school") }
  let!(:laoshi) { word("老師", "lǎoshī", "ㄌㄠˇ ㄕ", score: 6, meaning: "teacher") }

  before do
    sentence("我們學校很大。", %w[我們 學校 很 大 。], meaning: "Our school is big.")
    sentence("學校有老師。", %w[學校 有 老師 。], meaning: "The school has teachers.")
    sentence("我喜歡貓。", %w[我 喜歡 貓 。], meaning: "I like cats.")
  end

  describe "the dictionary mode" do
    it "finds an entry by hanzi, by pinyin and by zhuyin" do
      {q: "學校", pinyin: "xue2xiao4", zhuyin: "ㄒㄩㄝˊㄒㄧㄠˋ"}.each do |field, value|
        get("/search", params: {field => value})

        expect(response).to(have_http_status(:ok))
        expect(response.body).to(include("學校"), "expected #{field}=#{value} to find 學校")
      end
    end

    it "narrows to the kinds that are ticked" do
      word("學", "xué", "ㄒㄩㄝˊ", score: 2, kind: :character, meaning: "to learn")

      get("/search", params: {pinyin: "xue2", kinds: ["character"]})
      expect(response.body).to(include("學"))

      get("/search", params: {q: "學校", kinds: ["character"]})
      expect(response.body).to(include(I18n.t("search.empty", query: "學校")))
    end

    it "makes the three fields stack" do
      get("/search", params: {q: "學校", pinyin: "lao3shi1"})

      expect(response.body).to(include(I18n.t("search.empty", query: "學校 lao3shi1")))
    end
  end

  describe "the sentence mode" do
    def concordance_lines
      Nokogiri::HTML5(response.body).css("mark").map { |node| node.parent.text.strip }
    end

    it "returns sentences with the word marked in them" do
      get("/search", params: {q: "學校", sentences: "1"})

      expect(response).to(have_http_status(:ok))
      expect(concordance_lines).to(include("我們學校很大。").or(include("學校有老師。")))
      expect(Nokogiri::HTML5(response.body).css("mark").map(&:text)).to(all(eq("學校")))
    end

    it "asks for every word at once when the query holds several" do
      get("/search", params: {q: "學校老師", sentences: "1"})

      expect(concordance_lines).to(eq(["學校有老師。", "學校有老師。"]))
    end

    it "keeps out sentences the level filter excludes" do
      get("/search", params: {q: "學校", sentences: "1", levels: {"tocfl" => "Novice1"}})

      expect(response.body).to(include(I18n.t("search.empty", query: "學校")))
    end

    it "shows the translation next to the sentence" do
      get("/search", params: {q: "學校", sentences: "1"})

      expect(response.body).to(include("Our school is big.").or(include("The school has teachers.")))
    end

    it "pages ten at a time" do
      12.times { |index| sentence("學校#{index}好。", ["學校", "好", "。"], difficulty: 10 + index) }

      get("/search", params: {q: "學校", sentences: "1"})
      rows = Nokogiri::HTML5(response.body).css("mark").size
      expect(rows).to(be <= 10)
      expect(response.body).to(include(I18n.t("words.page", page: 1, pages: 2)))
    end
  end

  describe "the compatibility check" do
    it "says how often two words stand together and shows an example" do
      get("/search", params: {q: "學校老師"})

      expect(response.body).to(include(I18n.t("search.compatibility")))
      expect(response.body).to(include(I18n.t("search.pair_together", count: 1)))
    end

    it "names the set phrase when the dictionary holds one" do
      word("吃", "chī", "ㄔ", score: 3, kind: :character, meaning: "to eat")
      word("藥", "yào", "ㄧㄠˋ", score: 20, kind: :character, meaning: "medicine")
      word("吃藥", "chīyào", "ㄔ ㄧㄠˋ", score: 40, kind: :collocation, meaning: "to take medicine")

      get("/search", params: {q: "吃 藥"})

      expect(response.body).to(include(I18n.t("search.compatibility")))
      expect(response.body).to(include(I18n.t("search.pair_is_collocation")))
    end

    it "checks a measure word against its noun" do
      create(
        :lexeme,
        kind: :measure_word,
        text: "隻",
        score: 30,
        readings: {"pinyin" => "zhī", "zhuyin" => "ㄓ"},
        meanings: {"en" => "for animals"}
      )
      word(
        "貓",
        "māo",
        "ㄇㄠ",
        score: 40,
        kind: :character,
        meaning: "cat",
        data: {"classifiers" => [{"text" => "隻", "main" => true}]}
      )

      get("/search", params: {q: "隻貓"})

      expect(response.body).to(include(I18n.t("search.classifier_main", measure: "隻", noun: "貓")))
    end
  end

  describe "the panel" do
    it "still answers the quick fragment" do
      get("/search", params: {q: "學校", frame: "1"})

      expect(response.body).to(include("學校"))
      expect(response.body).not_to(include("<html"))
    end
  end
end
