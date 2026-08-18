# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sitemap", :no_auth do
  it "lists one child sitemap per section and stays free of a locale prefix" do
    get("/sitemap.xml")

    expect(response).to(have_http_status(:ok))
    expect(response.media_type).to(eq("application/xml"))
    expect(response.body).to(include("<sitemapindex"))
    expect(response.body).to(include("/sitemaps/pages.xml"))
    expect(response.body).not_to(include("/en/sitemap"))
  end

  it "offers every locale of a page as an alternate of the same address" do
    get("/sitemaps/pages.xml")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("<loc>http://www.example.com/en/dict</loc>"))
    expect(response.body).to(include("hreflang=\"ru\" href=\"http://www.example.com/ru/dict\""))
    expect(response.body).to(include("hreflang=\"x-default\" href=\"http://www.example.com/en/dict\""))
  end

  it "carries an entry for a character that has a reading and skips one that has nothing" do
    create(:lexeme, kind: :character, text: "水", readings: {"zhuyin" => "ㄕㄨㄟˇ"})
    create(:lexeme, kind: :character, text: "㐀")

    get("/sitemaps/characters.xml")

    expect(response.body).to(include("/characters/#{ERB::Util.url_encode("水")}"))
    expect(response.body).not_to(include("/characters/#{ERB::Util.url_encode("㐀")}"))
  end

  it "answers a section nobody publishes with a not found" do
    get("/sitemaps/nonsense.xml")

    expect(response).to(have_http_status(:not_found))
  end

  it "lets the shared cache hold the sitemap without splitting it per reader" do
    get("/sitemap.xml")

    expect(response.headers["Cache-Control"]).to(include("public"))
    expect(response.headers["Vary"]).to(eq("Accept-Encoding"))
    expect(response.headers["Set-Cookie"]).to(be_nil)
  end
end

RSpec.describe "Sitemap and data that may be absent", :no_auth do
  it "never advertises a page whose data has not been deployed" do
    allow(Huayu::TaiwanNames).to(receive(:available?).and_return(false))

    get("/sitemaps/pages.xml")

    expect(response).to(have_http_status(:ok))
    expect(response.body).not_to(include("/names"))
  end

  it "advertises it once the data is there" do
    allow(Huayu::TaiwanNames).to(receive(:available?).and_return(true))

    get("/sitemaps/pages.xml")

    expect(response.body).to(include("/en/names"))
  end
end
