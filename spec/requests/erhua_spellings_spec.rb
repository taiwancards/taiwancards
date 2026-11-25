# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Erhua spellings" do
  def headline
    Nokogiri::HTML(response.body).at_css("h1").text
  end

  it "opens the page of the base word for an erhua spelling and names the erhua form there" do
    create(:lexeme, kind: :word, text: "有空", meanings: {"en" => "to have free time"})

    get("/en/dict/#{CGI.escape("有空兒")}")

    expect(response).to(have_http_status(:ok))
    expect(headline).to(include("有空"))
    expect(headline).not_to(include("兒"))
    expect(response.body).to(include("to have free time"))
    expect(response.body).to(include("The erhua form 有空兒 is the Beijing-style variant"))
  end

  it "names the erhua form on the base page itself" do
    create(:lexeme, kind: :word, text: "聊天", meanings: {"en" => "to chat"})

    get("/en/dict/#{CGI.escape("聊天")}")

    expect(response.body).to(include("聊天兒"))
  end

  it "maps an erhua form to its listed base even when the stems differ" do
    create(:lexeme, kind: :word, text: "個子", meanings: {"en" => "height, stature"})

    get("/en/dict/#{CGI.escape("個兒")}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("height, stature"))
    expect(response.body).to(include("個兒"))
  end

  it "sends an erhua spelling of a single character to the character page" do
    create(:lexeme, :character, text: "邊", meanings: {"en" => "side, edge"})

    get("/en/dict/#{CGI.escape("邊兒")}")
    expect(response).to(redirect_to("/en/characters/#{CGI.escape("邊")}"))

    follow_redirect!
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("The erhua form 邊兒"))
  end

  it "marks the erhua form as Mandarin in the Japanese edition" do
    read_in("ja")
    create(:lexeme, kind: :word, text: "茶館", meanings: {"en" => "teahouse", "ja" => "茶館"})

    get("/ja/dict/#{CGI.escape("茶館兒")}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("北京風"))
    expect(response.body).not_to(include("〘茶館兒〙"))
    expect(response.body).to(match(/<[^>]+lang="zh-TW"[^>]*>茶館兒</))
  end

  it "keeps the Vietnamese note about Taiwan alone" do
    read_in("vi")
    create(:lexeme, kind: :word, text: "冰塊", meanings: {"en" => "ice cube", "vi" => "đá viên"})

    get("/vi/dict/#{CGI.escape("冰塊兒")}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("冰塊兒 rất ít được dùng ở Đài Loan"))
    expect(response.body).not_to(include("Bắc Kinh"))
  end

  it "does not turn a word where 兒 means child into its stem" do
    create(:lexeme, kind: :word, text: "孫", meanings: {"en" => "grandchild"})

    get("/en/dict/#{CGI.escape("孫兒")}")

    expect(response).to(have_http_status(:not_found))
  end

  it "finds the base word when the erhua spelling is searched" do
    create(:lexeme, kind: :word, text: "一半", meanings: {"en" => "half"})

    results = Lexemes::Search.new(user: nil).call("一半兒").results

    expect(results.map { |result| [result.lexeme.text, result.tier] }).to(include(["一半", Lexemes::Search::EXACT]))
  end
end
