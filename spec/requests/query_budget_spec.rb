# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Query budget" do
  let!(:source) do
    ContentSource.create!(
      slug: "spoken",
      name: "Spoken",
      license_commercial: true,
      register: :colloquial,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Spoken."
    )
  end

  def character!(text, index)
    create(
      :lexeme,
      :character,
      text: text,
      readings: {"pinyin" => "shì", "zhuyin" => "ㄕˋ"},
      meanings: {"en" => "meaning", "ru" => "значение"},
      data: {"moe_index" => index, "radical" => text, "freq_rank" => index}
    )
  end

  def sentence!(text, word)
    lexeme = Lexeme.new(kind: :sentence, text: text, meanings: {"en" => "gloss", "ru" => "перевод"})
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    SentenceWord.create!(sentence: lexeme, lexeme: word, gdex: 10)
    lexeme
  end

  before do
    chars = %w[長 話 說 讀 書 學 生 老 師 好].each_with_index.map { |text, index|
      character!(text, index + 1)
    }
    words = %w[長話 說話 讀書 學生 老師].map.with_index do |text, index|
      word = create(
        :lexeme,
        text: text,
        meanings: {"en" => "meaning", "ru" => "значение"},
        data: {"freq_rank" => index}
      )
      text.chars.each_with_index do |char, position|
        child = chars.find { |candidate| candidate.text == char }
        LexemeLink.create!(parent: word, child: child, position: position) if child
      end

      word
    end

    words.each_with_index { |word, index| 3.times { |n| sentence!("#{word.text}的句子#{index}#{n}。", word) } }
  end

  {
    "/" => 4,
    "/characters" => 8,
    "/characters/%E9%95%B7" => 14,
    "/dict" => 10,
    "/dict/%E5%AD%B8%E7%94%9F" => 22
  }.each do |path, budget|
    it "keeps #{path} under #{budget} queries for a guest" do
      get(path)
      expect(response).to(have_http_status(:ok))

      report = count_queries { get(path) }
      expect(report).to(issue_at_most(budget))
    end
  end
end
