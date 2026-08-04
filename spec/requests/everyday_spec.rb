# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Taiwan everyday vocabulary" do
  let(:path) { Rails.root.join("tmp/everyday_spec.json") }

  let(:entries) {
    [
      {
        "text" => "珍奶",
        "pinyin" => "zhēnnǎi",
        "en" => "bubble tea",
        "ru" => "чай с тапиокой",
        "origin" => "abbreviation",
        "register" => "casual",
        "domain" => "food",
        "mainland" => "珍珠奶茶"
      },
      {
        "text" => "三小",
        "pinyin" => "sánxiǎo",
        "en" => "what the hell",
        "ru" => "какого чёрта",
        "origin" => "hokkien",
        "register" => "vulgar",
        "domain" => "slang"
      },
      {"text" => "壞掉", "pinyin" => "huàidiào", "en" => "broken", "origin" => "nonsense", "register" => "casual"}
    ]
  }

  before { path.write(entries.to_json) }
  after { path.delete if path.exist? }

  def import
    Huayu::TaiwanEverydayImporter.new(path:).call
  end

  it "imports entries and skips ones with an unknown origin" do
    result = import

    expect(result.imported).to(eq(2))
    expect(result.skipped).to(eq(1))
    expect(Lexeme.find_by(text: "壞掉")).to(be_nil)
  end

  it "derives zhuyin from pinyin and records the Taiwan metadata" do
    import

    lexeme = Lexeme.find_by(text: "珍奶")
    expect(lexeme.readings["zhuyin"]).to(eq("ㄓㄣ ㄋㄞˇ"))
    expect(lexeme.data).to(include("taiwan_only" => true, "origin" => "abbreviation", "mainland" => "珍珠奶茶"))
    expect(lexeme.restricted).to(be(false))
  end

  it "gathers them into one studiable collection and is idempotent" do
    import
    import

    collection = Collection.find_by(kind: :everyday)
    expect(collection.lexemes.count).to(eq(2))
    expect(Lexeme.where(text: "珍奶").count).to(eq(1))
  end

  it "opens on situations instead of one long list" do
    import
    sign_in(create(:user))

    get(everyday_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("everyday.scenarios.food"), I18n.t("everyday.scenarios.slang")))
    expect(response.body).to(include(everyday_path(area: "slang")))
    expect(response.body).not_to(include(dict_entry_path(text: "三小")))
  end

  it "lists the words once a situation is picked" do
    import
    sign_in(create(:user))

    get(everyday_path(area: "slang"))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("三小"))
    expect(response.body).to(include(I18n.t("everyday.registers.vulgar")))
    expect(response.body).to(include(I18n.t("everyday.make_deck_button")))
  end

  it "filters by domain" do
    import
    sign_in(create(:user))

    get(everyday_path(area: "food"))

    expect(response.body).to(include("珍奶"))
    expect(response.body).not_to(include("三小"))
  end

  it "shows a word once even after a classifier moved it to collocation" do
    import
    Lexeme.find_by!(text: "珍奶").update_columns(kind: Lexeme.kinds[:collocation])
    import

    get(everyday_path(area: "food"))

    expect(Lexeme.where(text: "珍奶").count).to(eq(1))
    expect(response.body.scan(/>珍奶</).size).to(eq(1))
  end

  it "lets a curated rank put an entry ahead of its tier" do
    path.write(
      [
        entries.first.merge("tier" => 1, "tag" => "超商"),
        entries
          .first
          .merge("text" => "萊爾富", "pinyin" => "Lái'ěrfù", "tier" => 3, "tag" => "超商", "rank" => 1)
      ].to_json
    )
    import
    sign_in(create(:user))

    get(everyday_path(area: "food"))

    expect(response.body.index("萊爾富")).to(be < response.body.index("珍奶"))
  end

  it "draws the sugar and ice scales only in the drinks section" do
    path.write((entries.first(2).map { |e| e.merge("domain" => "drinks") }).to_json)
    import
    sign_in(create(:user))

    get(everyday_path(area: "drinks"))
    expect(response.body).to(include(I18n.t("everyday.scales.title"), "全糖", "無糖", "正常冰", "常溫"))

    get(everyday_path)
    expect(response.body).not_to(include(I18n.t("everyday.scales.title")))
  end

  it "says so plainly when nothing has been loaded" do
    sign_in(create(:user))

    get(everyday_path)

    expect(response.body).to(include(I18n.t("everyday.empty")))
  end

  it "drills speaking and hearing, not handwriting" do
    import

    lexeme = Lexeme.find_by(text: "珍奶")

    expect(Lexemes::Facets.for(lexeme)).to(eq(%w[recognition production reading tone]))
    expect(Lexemes::Facets.for(lexeme)).not_to(include("writing"))
  end

  it "mixes the top tier into the everyday study flow" do
    path.write((entries.first(2).map { |e| e.merge("tier" => 1) }).to_json)
    import
    user = sign_in(create(:user))
    Current.user = user
    create(:lexeme, kind: :word, text: "普通", data: {"freq_rank" => 1})

    fresh = Study::CardSet.new.send(:fresh_lexeme_ids, 4)

    everyday_ids = Lexeme.where(text: %w[珍奶 三小]).ids
    expect(fresh & everyday_ids).to(be_present)
  end

  it "builds a deck from exactly what the filter is showing, with chosen facets" do
    import
    sign_in(create(:user))
    food = Lexeme.find_by(text: "珍奶")

    post(
      desks_path,
      params: {lexeme_ids: [food.id], name: "Taiwan food", facets: %w[recognition production reading tone]}
    )

    deck = Collection.find_by(name: "Taiwan food")
    expect(deck.lexemes.map(&:text)).to(eq(["珍奶"]))
    expect(deck.study_facets).not_to(include("writing"))
  end

  it "offers a deck name that follows the active filter" do
    import
    sign_in(create(:user))

    get(everyday_path(area: "slang"))

    expect(response.body).to(include(I18n.t("everyday.domains.slang")))
    expect(response.body).to(include(I18n.t("everyday.make_deck_button")))
  end
end
