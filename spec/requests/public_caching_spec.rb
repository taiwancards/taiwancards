# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public caching" do
  REFERENCE_PAGES = %w[/grammar /tones /hanzi /variants /cangjie /practice/numbers /everyday /metro /chengyu].freeze

  def session_cookie = response.headers["Set-Cookie"].to_s

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
        expect(session_cookie).not_to(include("_taiwancards_session"), "#{path} opened a session")
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
      expect(session_cookie).not_to(include("_taiwancards_session"))
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

    it "keeps the request token, so the study controls still submit" do
      guarding_forgery { get("/grammar") }

      expect(response.body).to(include("csrf-token"))
    end
  end
end
