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

  it "no longer guesses grammar from a sentence" do
    source = ContentSource.create!(
      slug: "spoken",
      name: "Spoken",
      license_commercial: true,
      register: :colloquial,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Spoken."
    )
    sentence = Lexeme.new(
      kind: :sentence,
      text: "我是學生。",
      meanings: {"en" => "I am a student."},
      data: {"segments" => %w[我 是 學生]}
    )
    sentence.lexeme_content_sources.build(content_source: source)
    sentence.save!

    get("/sentences/#{sentence.to_param}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).not_to(include("/grammar/shi"))
  end
end
