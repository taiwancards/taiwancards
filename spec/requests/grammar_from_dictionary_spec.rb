# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Grammar reached from the dictionary" do
  it "offers the point directly when a word carries only one" do
    create(:lexeme, kind: :word, text: "如果", meanings: {"en" => "if"})

    get("/dict/#{CGI.escape("如果")}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("/grammar/"))
    expect(response.body).not_to(include("form="))
  end

  it "offers the filtered list when a word carries several" do
    create(:lexeme, kind: :character, text: "的", meanings: {"en" => "of"})

    get("/characters/#{CGI.escape("的")}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("form=#{CGI.escape("的")}"))
  end

  it "says nothing about grammar for an ordinary word" do
    create(:lexeme, kind: :word, text: "咖啡", meanings: {"en" => "coffee"})

    get("/dict/#{CGI.escape("咖啡")}")

    expect(response.body).not_to(include("/grammar/"))
  end

  it "lists only the points built on the requested form" do
    get("/grammar", params: {form: "的"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(grammar_lesson_path("de-possessive")))
    expect(response.body).not_to(include(grammar_lesson_path("shenme")))
  end

  def spoken_sentence(text)
    source = ContentSource.find_or_create_by!(slug: "spoken") do |row|
      row.assign_attributes(
        name: "Spoken",
        license_commercial: true,
        register: :colloquial,
        enabled: true,
        enabled_for_admins: true,
        attribution: "Spoken."
      )
    end

    sentence = Lexeme.new(kind: :sentence, text:, meanings: {"en" => "-"}, data: {"segments" => text.chars})
    sentence.lexeme_content_sources.build(content_source: source)
    sentence.save!
    sentence
  end

  it "never guesses grammar from the characters of a sentence" do
    sentence = spoken_sentence("我們都是咖啡店的大學生。")
    expect(Huayu::GrammarLessons.for_sentence(sentence)).to(be_empty)

    get("/sentences/#{sentence.to_param}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).not_to(include("/grammar/"))
  end

  it "names the lessons that teach with this very sentence" do
    sentence = spoken_sentence("我是學生。")

    get("/sentences/#{sentence.to_param}")

    expect(response.body).to(include("In the grammar lessons"))
    expect(response.body).to(include("/en/grammar/shi"))
  end
end
