# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Board games" do
  def import(entries)
    path = Rails.root.join("tmp/games_request_spec.json")
    path.write(entries.to_json)
    Huayu::GamesImporter.new(path:).call
  ensure
    path.delete if path.exist?
  end

  def entry(text, game, category, extra = {})
    {
      "text" => text,
      "pinyin" => "cè shì",
      "en" => "gloss #{text}",
      "ru" => "тест",
      "game" => game,
      "category" => category
    }.merge(extra)
  end

  it "shows the empty notice when nothing is imported yet" do
    get(games_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("games.empty")))
  end

  it "opens on mahjong and lists its categories" do
    import(
      [
        entry("聽牌", "mahjong", "call", "tier" => 1),
        entry("屁胡", "mahjong", "pattern", "note_ru" => "рука без тая", "note_en" => "a zero-tai hand"),
        entry("楚河漢界", "xiangqi", "board")
      ]
    )

    get(games_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("games.leads.mahjong.title")))
    expect(response.body).to(include(I18n.t("games.categories.call")))
    expect(response.body).to(include(I18n.t("games.categories.pattern")))
    expect(response.body).to(include(dict_entry_path(text: "屁胡")))
    expect(response.body).not_to(include("楚河漢界"))
  end

  it "switches boards by a real link and keeps the tabs addressable" do
    import([entry("聽牌", "mahjong", "call"), entry("貼目", "go", "rule")])

    get(games_path)
    expect(response.body).to(include(games_path(game: "go")))

    get(games_path(game: "go"))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("games.leads.go.title")))
    expect(response.body).to(include("貼目"))
    expect(response.body).not_to(include("聽牌"))
  end

  it "falls back to the first board when the name is unknown" do
    import([entry("聽牌", "mahjong", "call")])

    get(games_path(game: "backgammon"))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("games.leads.mahjong.title")))
  end

  it "renders the Russian explanations next to every term" do
    import(
      [
        entry(
          "過水",
          "mahjong",
          "call",
          "note_ru" => "отказ от выигрыша",
          "note_en" => "declining a win"
        )
      ]
    )

    in_locale(:ru) { get(games_path) }

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("games.title", locale: :ru)))
    expect(response.body).to(include("отказ от выигрыша"))
  end

  it "offers the study menu to signed-in users" do
    import([entry("圍棋", "go", "game")])
    sign_in(create(:user))

    get(games_path(game: "go"))

    expect(response.body).to(include(I18n.t("everyday.make_deck_button")))
    expect(response.body).to(include(quick_add_path))
  end

  it "keeps the readings and the meanings of a word the everyday collection owns" do
    lexeme = Lexemes::Upserter.new.word(
      "面子",
      readings: {"pinyin" => "miàn zi"},
      meanings: {"ru" => "лицо, репутация", "en" => "face, prestige"}
    )
    lexeme.update!(data: lexeme.data.merge("placements" => [{"domain" => "life"}]))

    import([entry("面子", "mahjong", "meld")])

    lexeme.reload
    expect(lexeme.readings["pinyin"]).to(eq("miàn zi"))
    expect(lexeme.meanings["ru"]).to(eq("лицо, репутация"))
    expect(lexeme.data.dig("game", "category")).to(eq("meld"))
  end
end
