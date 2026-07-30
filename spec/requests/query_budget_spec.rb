# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Query budget" do
  let(:source) do
    ContentSource.create!(
      name: "Fixture corpus",
      slug: "fixture-corpus",
      register: :publicistic,
      license_name: "CC0 1.0",
      license_commercial: true,
      license_derivatives: true,
      attribution: "Fixture corpus"
    )
  end

  def character(text, **data)
    Lexeme.create!(
      kind: :character,
      text:,
      readings: {"pinyin" => "shi", "zhuyin" => "ㄕ"},
      meanings: {"en" => "gloss for #{text}"},
      data: {"freq_rank" => 10, "strokes" => 5}.merge(data)
    )
  end

  def word(text, **data)
    Lexeme.create!(
      kind: :word,
      text:,
      readings: {"pinyin" => "ci", "zhuyin" => "ㄘ"},
      meanings: {"en" => "gloss for #{text}"},
      data: {"freq_rank" => 20}.merge(data)
    )
  end

  def sentence(text)
    lexeme = Lexeme.new(kind: :sentence, text:, meanings: {"en" => "translation of #{text}"}, data: {"segments" => []})
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    SentenceProfile.create!(lexeme:, han_length: text.length, difficulty: 1)
    lexeme
  end

  describe "the dictionary index" do
    before { 40.times { |index| word("詞彙#{index}") } }

    it "reads the page without a query per entry, whatever the page holds" do
      small = count_queries { get(dict_path) }
      40.times { |index| word("補詞#{index}") }
      large = count_queries { get(dict_path) }

      expect(response).to(have_http_status(:ok))
      expect(large.count).to(be <= small.count)
      expect(large).to(repeat_no_query_more_than(3))
    end
  end

  describe "a dictionary entry with sentences" do
    let(:entry) { word("學習") }

    before do
      12.times do |index|
        example = sentence("我在學習中文#{index}。")
        SentenceWord.create!(sentence: example, lexeme: entry, gdex: 900 - index)
      end
    end

    it "loads every sentence, its profile and its sources without a per-row query" do
      cookies[DetailLevelHelper::DETAIL_COOKIE] = Lexemes::DetailDefault::FULL
      report = count_queries { get(dict_entry_path(entry.text)) }

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("我在學習中文0。"))
      expect(report).to(repeat_no_query_more_than(3))
    end
  end

  describe "the sentence browser" do
    before { 12.times { |index| sentence("這是第#{index}個句子。") } }

    it "loads a page of sentences with their sources in a fixed number of queries" do
      report = count_queries { get(sentences_path) }

      expect(response).to(have_http_status(:ok))
      expect(report).to(repeat_no_query_more_than(3))
    end
  end

  describe "the character grid" do
    before { 60.times { |index| character([0x4E00 + index].pack("U")) } }

    it "marks studied characters with one lookup rather than one per cell" do
      report = count_queries { get(characters_path) }

      expect(response).to(have_http_status(:ok))
      expect(report).to(repeat_no_query_more_than(3))
    end
  end

  describe "the phrasebook" do
    before { %w[廁所 洗手間 衛生紙].each { |text| word(text) } }

    it "resolves every linked entry in one lookup" do
      report = count_queries { get(phrases_path(scene: "restroom")) }

      expect(response).to(have_http_status(:ok))
      expect(report).to(repeat_no_query_more_than(3))
    end
  end
end
