# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Typing modes" do
  before do
    10.times do |i|
      create(
        :lexeme,
        kind: :character,
        text: "字#{i}",
        meanings: {"en" => "char #{i}"},
        readings: {"zhuyin" => "ㄗˋ", "pinyin" => "zì"},
        data: {"freq_rank" => i + 1}
      )
    end
  end

  it "starts a complete beginner on pinyin, not on characters" do
    get("/practice/typing")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("typing.mode_hint.pinyin"))))
  end

  it "prompts with pinyin rather than an unknown character" do
    get("/practice/typing", params: {mode: "pinyin"})

    expect(response.body).to(include("&quot;prompt&quot;:&quot;zì&quot;"))
  end

  it "uses only characters the learner has actually studied" do
    studied = Lexeme.where(kind: :character).first(6)
    studied.each do |lexeme|
      Lexemes::Activator.new.call(lexeme)
      LexemeMemory.owned_by(@authenticated_user).where(lexeme:).update_all(state: LexemeMemory.states[:review])
    end

    get("/practice/typing", params: {mode: "hanzi"})

    expect(response.body).to(include("&quot;prompt&quot;:&quot;#{studied.first.text}&quot;"))
    expect(response.body).not_to(include("&quot;prompt&quot;:&quot;字9&quot;"))
  end

  it "falls back to pinyin and says so when too little has been studied" do
    get("/practice/typing", params: {mode: "hanzi"})

    expect(response.body).to(include(CGI.escapeHTML(I18n.t("typing.fell_back"))))
  end

  it "defaults someone with a level to characters" do
    @authenticated_user.update!(prefs: {"level" => "3"})
    Lexeme.where(kind: :character).each do |lexeme|
      Lexemes::Activator.new.call(lexeme)
      LexemeMemory.owned_by(@authenticated_user).where(lexeme:).update_all(state: LexemeMemory.states[:review])
    end

    get("/practice/typing")

    expect(response.body).to(include(CGI.escapeHTML(I18n.t("typing.mode_hint.hanzi"))))
  end
end
