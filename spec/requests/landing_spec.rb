# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Landing page" do
  it "welcomes a visitor who is not signed in", :no_auth do
    get(root_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("landing.hero.heading")))
    expect(response.body).to(include(login_path))
  end

  it "stays reachable for a signed-in person and offers a way back into the app" do
    get(root_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(desk_path))
    expect(response.body).not_to(include(login_path))
  end

  it "states plainly what the app is, by its own name", :no_auth do
    get(root_path)

    expect(response.body).to(include(CGI.escapeHTML(I18n.t("meta.description"))))
    %i[en ru].each { |locale| expect(I18n.t("meta.description", locale:)).to(include("TaiwanCards")) }
  end

  it "says what the app is and what it is not, before anything else", :no_auth do
    get(root_path)

    is = response.body.index(CGI.escapeHTML(I18n.t("landing.is.heading")))
    isnt = response.body.index(CGI.escapeHTML(I18n.t("landing.isnt.heading")))

    expect(is).to(be_present)
    expect(isnt).to(be > is)
    expect(isnt).to(be < response.body.index(CGI.escapeHTML(I18n.t("landing.final.heading"))))
  end

  it "names what it will never become, in both locales", :aggregate_failures do
    %i[en ru].each do |locale|
      %w[game machine decks china course teacher ads].each do |key|
        expect(I18n.t("landing.isnt.items.#{key}", locale:)).to(be_present)
      end
    end
  end

  it "offers the visitor the other language as a plain link, needing no session", :no_auth do
    get("/en")

    expect(response.body).to(include("href=\"/ru\""))
    expect(response.body).not_to(include("/locale/"))
  end

  it "links its privacy policy and terms from the home page", :no_auth do
    get(root_path)

    expect(response.body).to(include(privacy_path, terms_path))
  end

  it "switches language only when the visitor asks, and moves the address with it", :no_auth do
    post("/locale/ru", headers: {"HTTP_REFERER" => "http://www.example.com/en"})

    expect(response).to(redirect_to("http://www.example.com/ru"))
    follow_redirect!
    expect(response.body).to(include(I18n.t("landing.hero.heading", locale: :ru)))
  end

  it "remembers the choice for a visitor who arrives with no prefix at all", :no_auth do
    post("/locale/ru", headers: {"HTTP_REFERER" => "http://www.example.com/en"})

    raw_get("/")

    expect(response).to(redirect_to("/ru"))
  end

  it "lets the path segment beat a locale smuggled in through the query string", :no_auth do
    get("/ru?locale=en")

    expect(response.body).to(include(I18n.t("landing.hero.heading", locale: :ru)))
  end

  it "never advertises restricted material", :no_auth do
    get(root_path)

    expect(response.body).not_to(include(textbook_path))
  end

  it "drops the signup pitch once the visitor is signed in" do
    get(root_path)

    expect(response.body).to(include(I18n.t("landing.open_app")))
    expect(response.body).not_to(include(I18n.t("landing.final.heading")))
    expect(response.body).not_to(include(I18n.t("landing.final.body")))
  end

  it "still pitches to a signed-out visitor", :no_auth do
    get(root_path)

    expect(response.body).to(include(I18n.t("landing.final.heading")))
  end

  it "announces the official audio and says whose it is", :no_auth do
    get(root_path)

    expect(response.body).to(include(I18n.t("landing.quality.items.audio.title")))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("landing.quality.items.audio.body"))))
  end

  it "keeps the sources one click away", :no_auth do
    get(root_path)

    expect(response.body).to(include(licenses_path))
  end

  it "orders the counts from radicals up to phrases", :no_auth do
    get(root_path)

    order = %i[radicals characters words].map { |key| response.body.index(I18n.t("landing.counts.#{key}")) }
    expect(order.compact).to(eq(order.compact.sort))
    expect(response.body).not_to(include("landing.counts.ranked"))
  end

  it "still states what the app is somewhere a reviewer can read it", :no_auth do
    get(root_path)

    expect(response.body).to(include(CGI.escapeHTML(I18n.t("landing.hero.heading"))))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("landing.hero.lede.variety").last)))
  end

  it "carries the app name that the OAuth consent screen is configured with", :no_auth do
    get(root_path)

    expect(I18n.t("app.name")).to(eq("TaiwanCards"))
    expect(response.body).to(include("TaiwanCards"))
  end

  it "explains what Google data is requested and why on the privacy page, without a login", :no_auth do
    get(privacy_path)

    expect(response.body).to(include(I18n.t("privacy_google.heading")))
    %w[signin drive limits].each do |key|
      expect(response.body).to(include(CGI.escapeHTML(I18n.t("privacy_google.#{key}"))))
    end

    expect(response.body).to(include("drive.file"))
  end

  it "reaches the privacy policy and terms from the home page, which is what a reviewer checks", :no_auth do
    get(root_path)

    expect(response.body).to(include(privacy_path))
    expect(response.body).to(include(terms_path))
  end

  it "states the purpose in English by default, which is what a reviewer sees", :no_auth do
    get(root_path)

    expect(I18n.default_locale).to(eq(:en))
    expect(response.body).to(include("ad-free flashcard app for learning Taiwanese Mandarin"))
  end

  it "promises no advertising freely, and promises no price only once", :no_auth do
    {en: [/\bfree\b/i, /\bno ads\b/i], ru: [/бесплатн/i, /реклам/i]}.each do |locale, (price, ads)|
      get("/#{locale}")
      text = response.body.gsub(/<[^>]+>/, " ")

      expect(text.scan(price).length).to(eq(1))
      expect(text.scan(ads).length).to(be >= 1)
    end
  end

  it "shows the same neutral card whatever page is shared", :no_auth do
    [root_path, login_path, privacy_path].each do |path|
      get(path)

      expect(response.body).to(include("content=\"#{I18n.t("meta.share_title")}\" property=\"og:title\""))
      expect(response.body).to(include("og.png"))
      expect(response.body).to(include("content=\"summary_large_image\""))
    end
  end

  it "keeps marketing words out of the share text" do
    %i[en ru].each do |locale|
      text = "#{I18n.t("meta.share_title", locale:)} #{I18n.t("meta.share_description", locale:)}"
      expect(text).not_to(match(/free|бесплат|ad-free|без рекламы|подписк|subscription/i))
    end
  end
end
