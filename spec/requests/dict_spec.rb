# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dictionary" do
  let!(:word) do
    create(
      :lexeme,
      kind: :word,
      text: "學校",
      readings: {"pinyin" => "xuéxiào", "zhuyin" => "ㄒㄩㄝˊ ㄒㄧㄠˋ"},
      meanings: {"en" => "school", "ru" => "школа"},
      data: {"pos" => "N"}
    )
  end

  let!(:collocation) do
    create(
      :lexeme,
      kind: :collocation,
      text: "超商",
      meanings: {"en" => "convenience store", "ru" => "круглосуточный магазинчик"}
    )
  end

  it "lists entries with a search filter" do
    get("/dict", params: {q: "school"})
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("學校"))
    expect(response.body).to(include("/dict/"))
  end

  it "lists words and collocations together" do
    get("/dict")
    expect(response.body).to(include("學校"))
    expect(response.body).to(include("超商"))
  end

  it "orders by frequency when sort=freq is requested" do
    create(:lexeme, kind: :word, text: "常見", meanings: {"en" => "common"}, data: {"freq_rank" => 3})
    create(:lexeme, kind: :word, text: "罕見", meanings: {"en" => "rare"}, data: {"freq_rank" => 900})

    get("/dict", params: {sort: "freq"})
    expect(response).to(have_http_status(:ok))
    expect(response.body.index("常見")).to(be < response.body.index("罕見"))
  end

  it "shows a word entry with its component characters" do
    create(:lexeme, :character, text: "學", readings: {"pinyin" => "xué"})
    LexemeLink.create!(parent: word, child: Lexeme.find_by(text: "學"), position: 0)

    get("/dict/#{CGI.escape("學校")}")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("школа").or(include("school")))
    expect(response.body).to(include("/characters/"))
  end

  it "resolves a 臺 spelling through its 台 twin and back" do
    create(:lexeme, kind: :word, text: "台南", meanings: {"en" => "Tainan", "ru" => "Тайнань"})
    create(:lexeme, kind: :word, text: "月臺", meanings: {"en" => "platform", "ru" => "перрон"})

    get("/dict/#{CGI.escape("臺南")}")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Tainan").or(include("Тайнань")))

    get("/dict/#{CGI.escape("月台")}")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("platform").or(include("перрон")))
  end

  it "shows the same entry for both spellings and links them" do
    create(
      :lexeme,
      kind: :word,
      text: "臺獨",
      meanings: {
        "en" => "Taiwan independence (position and movement)",
        "ru" => "тайваньская независимость"
      }
    )
    create(
      :lexeme,
      kind: :word,
      text: "台獨",
      meanings: {"en" => "independence", "ru" => "независимость"}
    )

    get("/dict/#{CGI.escape("台獨")}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Taiwan independence (position and movement)"))
    expect(response.body).to(include("/dict/#{CGI.escape("臺獨")}"))
  end

  it "keeps the senses of the other spelling on the page" do
    plain = create(:lexeme, kind: :word, text: "舞台", meanings: {"en" => "stage", "ru" => "сцена"})
    rich = create(:lexeme, kind: :word, text: "舞臺", meanings: {"en" => "stage", "ru" => "сцена"})
    rich.senses.create!(position: 0, meanings: {"ru" => "площадка, на которой играют"})

    get("/ru/dict/#{CGI.escape("舞臺")}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("площадка, на которой играют"))
    expect(response.body).to(include("/ru/dict/#{CGI.escape("舞臺")}"))
    expect(plain.reload.senses).to(be_empty)
  end

  it "shows a collocation on the same entry page" do
    get("/dict/#{CGI.escape("超商")}")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("超商"))
  end

  it "activates an entry into the study set" do
    expect do
      post("/dict/#{CGI.escape("學校")}/activate")
    end
      .to(change(LexemeMemory.active, :count).by_at_least(1))
    expect(response).to(redirect_to("/en/dict/#{CGI.escape("學校")}"))
  end

  it "redirects the old word and collocation urls" do
    get("/words/#{CGI.escape("學校")}")
    expect(response).to(redirect_to("/en/dict/#{CGI.escape("學校")}"))

    get("/collocations/#{CGI.escape("超商")}")
    expect(response).to(redirect_to("/en/dict/#{CGI.escape("超商")}"))

    get("/words")
    expect(response).to(redirect_to("/en/dict"))
  end

  it "returns not found for an unknown entry" do
    get("/dict/#{CGI.escape("不存在的詞")}")
    expect(response).to(have_http_status(:not_found))
  end
end
