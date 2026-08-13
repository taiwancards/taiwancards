# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Grammar pages" do
  it "keeps every level in the switcher and marks only the chosen one" do
    get("/grammar", params: {level: 2})

    expect(response).to(have_http_status(:ok))
    (1..5).each { |level| expect(response.body).to(include("/grammar?level=#{level}")) }
    expect(response.body.scan(/aria-current="page"/).size).to(eq(1))
  end

  it "marks the all-levels tab when no level is chosen" do
    get("/grammar")

    expect(response.body.scan(/aria-current="page"/).size).to(eq(1))
    expect(response.body).to(include("/grammar?level=5"))
  end

  it "opens with linked cards for the words the point is about" do
    create(:lexeme, kind: :word, text: "一樣", meanings: {"en" => "the same"})

    get("/grammar/gen-yiyang-same")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("/dict/#{CGI.escape("一樣")}"))
  end

  it "sets the Chinese in the explanation apart and reads it in zhuyin" do
    get("/grammar/shi")

    expect(response.body).to(include("zh-term"))
    expect(response.body).to(include("lang=\"zh-TW\""))
    expect(response.body).to(include("ㄕ"))
  end

  it "no longer credits the source list at the foot of the page" do
    get("/grammar/shi")
    expect(response.body).not_to(include("Taiwan Benchmarks for the Chinese Language"))

    get("/grammar")
    expect(response.body).not_to(include("Taiwan Benchmarks for the Chinese Language"))
  end

  it "sends the numbers point on to the numbers drill" do
    get("/grammar/numbers")

    expect(response.body).to(include(practice_numbers_path))
  end

  it "teaches both number rules that trip learners up" do
    get("/grammar/numbers")

    page = Nokogiri::HTML(response.body)
    page.css("rt, rp").each(&:remove)
    text = page.text

    expect(text).to(include("一百零八"))
    expect(text).to(include("一百八"))
  end

  it "shows a reading once, where the word is introduced" do
    get("/grammar/shi")

    page = Nokogiri::HTML(response.body)
    prose = page.css("section.grammar-prose").first
    expect(prose.css(".reading").size).to(be >= 3)
    expect(prose.css(".zy-reading").first.text).to(include("ㄕ"))
    expect(prose.css(".py-reading").first.text).to(include("sh"))
  end

  it "puts each example on its own line with a quoted translation" do
    get("/grammar/shi")

    examples = Nokogiri::HTML(response.body).css("section.grammar-prose .grammar-example")
    expect(examples.size).to(be >= 2)
    expect(examples.first.css(".zh-line").text).to(be_present)
    expect(examples.first.css(".grammar-gloss").text).to(start_with("“"))
  end

  it "gives a signed-out visitor zhuyin and holds the pinyin back", :no_auth do
    get("/grammar/shi")

    classes = Nokogiri::HTML(response.body).at("html")["class"]

    expect(classes).to(include("no-pinyin"))
    expect(classes).not_to(include("no-zhuyin"))
  end

  it "anchors explanations in the language, never in a country" do
    Huayu::GrammarLessons.taught.each do |lesson|
      %i[en ru].each do |locale|
        text = [lesson.title(locale), lesson.body(locale), lesson.tip(locale)].join(" ")
        expect(text).not_to(match(/советск|СССР|Soviet/i), "#{lesson.slug} (#{locale})")
      end
    end
  end
end
