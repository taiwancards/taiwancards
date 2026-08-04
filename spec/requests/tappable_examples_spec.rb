# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tappable examples" do
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

  let!(:word) { create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"}) }
  let!(:companion) { create(:lexeme, kind: :word, text: "喜歡", meanings: {"en" => "to like"}) }

  let!(:sentence) do
    lexeme = Lexeme.new(
      kind: :sentence,
      text: "我喜歡學校。",
      meanings: {"en" => "I like school."},
      data: {"segments" => %w[我 喜歡 學校]}
    )
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  before do
    sense = word
      .senses
      .create!(position: 0, gloss_zh: "上課的地方", meanings: {"en" => "school"}, content_source: source)
    sense.examples.create!(kind: :sentence, text: sentence.text, position: 0, content_source: source, lexeme: sentence)
    SentenceWord.create!(sentence:, lexeme: word, gdex: 500)
  end

  it "renders dictionary examples word by word with links" do
    get("/dict/#{CGI.escape("學校")}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(
      include("href=\"/en/dict/#{CGI.escape("喜歡")}\"").or(include("href=\"/en/dict/喜歡\""))
    )
    expect(response.body).to(include("喜歡"))
  end

  it "computes cloze text for a word inside its example" do
    helper = Object.new.extend(StudyHelper)

    expect(helper.cloze_text(sentence, word.text)).to(eq("我喜歡＿＿。"))
  end
end
