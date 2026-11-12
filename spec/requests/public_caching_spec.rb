# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public caching" do
  REFERENCE_PAGES = %w[
    /grammar
    /tones
    /hanzi
    /variants
    /cangjie
    /cangjie/lessons
    /practice/numbers
    /everyday
    /metro
    /chengyu
  ]
    .freeze

  def shareable_patterns
    Rails
      .application
      .routes
      .routes
      .filter_map do |route|
        pattern = route.path.spec.to_s
        next unless route.verb.split("|").include?("GET") && pattern.start_with?("(/:locale)")

        actions = "#{route.defaults[:controller]}_controller".camelize.safe_constantize.try(:public_cache_actions)
        next unless actions == :all || Array(actions).include?(route.defaults[:action])

        pattern.delete_prefix("(/:locale)").delete_suffix("(.:format)")
      end
      .uniq
  end

  def addresses(patterns, fixtures)
    patterns.filter_map { |pattern| pattern.match?(/[:*(]/) ? fixtures[pattern] : pattern }
  end

  def fixture_addresses
    collection = Collection.create!(kind: :tocfl, name: "TOCFL Band A · A1", level_tag: "A1", position: 2)
    create(:lexeme, text: "學校", readings: {"pinyin" => "xuéxiào", "zhuyin" => "ㄒㄩㄝˊ ㄒㄧㄠˋ"})
    create(:lexeme, :character, text: "學", readings: {"pinyin" => "xué", "zhuyin" => "ㄒㄩㄝˊ"})
    sentence = create(:lexeme, :sentence, text: "我們學校很大。", segments: %w[我們 學校 很 大 。])

    {
      "/tocfl/:id" => "/tocfl/#{collection.id}",
      "/dict/:text" => "/dict/#{CGI.escape("學校")}",
      "/characters/:text" => "/characters/#{CGI.escape("學")}",
      "/sentences/:id" => "/sentences/#{sentence.to_param}"
    }
  end

  def expect_shared(path)
    expect(response).to(have_http_status(:ok), path)
    expect(response.headers["Cache-Control"]).to(include("public", "s-maxage="), path)
    expect(response.headers["Set-Cookie"]).to(be_blank, "#{path} set a cookie")
  end

  def guarding_forgery
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  context("for a visitor with no account", :no_auth) do
    it "answers the reference sections without opening a session" do
      REFERENCE_PAGES.each do |path|
        get(path)

        expect(response).to(have_http_status(:ok), path)
        expect(response.headers["Set-Cookie"]).to(be_blank, "#{path} opened a session")
      end
    end

    it "lets a shared cache hold every page whose controller declares it shareable" do
      patterns = shareable_patterns
      paths = addresses(patterns, fixture_addresses)

      expect(patterns).to(include("/grammar", "/dict/:text"))
      expect(paths.size).to(be > 40)
      paths.each do |path|
        get(path)

        expect_shared(path)
      end
    end

    it "lets a shared cache hold the page, and the browser revalidate it" do
      get("/grammar")

      expect(response.headers["Cache-Control"]).to(include("public"))
      expect(response.headers["Cache-Control"]).to(include("s-maxage="))
      expect(response.headers["Cache-Control"]).to(include("max-age=0"))
    end

    it "leaves out the request token, since a shared copy could not carry a private one" do
      guarding_forgery { get("/grammar") }

      expect(response.body).not_to(include("csrf-token"))
    end

    it "still opens a session where one is needed, and keeps that page private" do
      get("/writing")

      expect(response.headers["Cache-Control"].to_s).not_to(include("public"))
    end

    it "keeps a page private once the reader has set how it should look" do
      PubliclyCacheable::PERSONAL.each do |name|
        cookies[name] = "kai"
        get("/grammar")

        expect(response.headers["Cache-Control"].to_s).not_to(
          include("public"),
          "#{name} was baked into a page a shared cache could hand to someone else"
        )
        cookies.delete(name)
      end
    end

    it "still shares the page with a reader who has set nothing" do
      get("/grammar")

      expect(response.headers["Cache-Control"]).to(include("public"))
    end

    it "shares it with a client that asks for anything at all, so the edge absorbs the crawlers" do
      get("/grammar", headers: {"HTTP_ACCEPT" => "*/*"})

      expect(response.headers["Cache-Control"]).to(include("s-maxage="))
      expect(response.headers["Set-Cookie"]).to(be_blank)
    end

    it "keeps a frame fragment out of the shared cache, so it cannot stand in for the page" do
      get("/en/grammar", headers: {"Turbo-Frame" => "anything"})

      expect(response.headers["Cache-Control"].to_s).not_to(include("public"))
      expect(response.headers["Cache-Control"].to_s).not_to(include("s-maxage"))
    end

    it "never offers a shared cache a format that only the Accept header asked for" do
      collection = Collection.create!(kind: :tocfl, name: "TOCFL Band A · A1", level_tag: "A1", position: 2)

      get("/en/tocfl/#{collection.id}", headers: {"HTTP_ACCEPT" => "text/csv"})

      expect(response.media_type).not_to(eq("text/csv"))
      expect(response.headers["Cache-Control"].to_s).not_to(include("public"))
    end

    it "still shares the spreadsheet a guest asked for by its address" do
      collection = Collection.create!(kind: :tocfl, name: "TOCFL Band A · A1", level_tag: "A1", position: 2)

      get("/en/tocfl/#{collection.id}.csv")

      expect(response.media_type).to(eq("text/csv"))
      expect(response.headers["Cache-Control"]).to(include("public"))
      expect(response.headers["Set-Cookie"]).to(be_blank)
    end

    it "lets the shared cache hold the festival calendar for an hour only, since it marks today" do
      get("/en/calendar")

      expect(response.headers["Cache-Control"]).to(include("public"))
      expect(response.headers["Cache-Control"]).to(include("s-maxage=3600"))
      expect(response.headers["Cache-Control"]).to(include("stale-while-revalidate=3600"))
    end

    it "switches language by address rather than by a form" do
      get("/ru/grammar")

      expect(response.body).to(include("href=\"/en/grammar\""))
      expect(response.body).not_to(include("/locale/"))
    end
  end

  context("for a signed in reader") do
    before { sign_in(create(:user)) }

    it "never lets a shared cache hold a page rendered for one person" do
      REFERENCE_PAGES.each do |path|
        get(path)

        expect(response.headers["Cache-Control"].to_s).not_to(include("public"), "#{path} was offered to a cache")
      end
    end

    it "keeps a reader's spreadsheet private" do
      collection = Collection.create!(kind: :tocfl, name: "TOCFL Band A · A1", level_tag: "A1", position: 2)

      get("/en/tocfl/#{collection.id}.csv")

      expect(response.media_type).to(eq("text/csv"))
      expect(response.headers["Cache-Control"].to_s).not_to(include("public"))
    end

    it "keeps the request token, so the study controls still submit" do
      guarding_forgery { get("/grammar") }

      expect(response.body).to(include("csrf-token"))
    end
  end
end
