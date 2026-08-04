# frozen_string_literal: true

require "rails_helper"

RSpec.describe Site::Exporter do
  let(:root) { Rails.root.join("tmp/site_spec") }
  let(:io) { StringIO.new }

  let(:app_url) { "https://study.example.test" }
  let(:assets_url) { "https://assets.example.test" }

  let(:site_url) { "https://taiwancards.example" }

  before do
    allow(ENV).to(receive(:[]).and_call_original)
    allow(ENV).to(receive(:fetch).and_call_original)
    allow(ENV).to(receive(:[]).with("ASSETS_BASE_URL").and_return(assets_url))
    allow(ENV).to(receive(:[]).with("SITE_URL").and_return(site_url))
    allow(ENV).to(receive(:[]).with("APP_URL").and_return(app_url))
    allow(ENV).to(receive(:fetch).with("SITE_URL").and_return(site_url))
    allow(ENV).to(receive(:fetch).with("APP_URL").and_return(app_url))
    SharedAssets.forget_stamps!
    described_class.new(root: root, io: io).call
  end

  after { SharedAssets.forget_stamps! }
  after { root.rmtree if root.exist? }

  def page(*parts) = root.join(*parts).read

  it "writes every page in both languages, and keeps the old addresses alive" do
    expect(root.glob("**/index.html").map { |file| file.relative_path_from(root).to_s }).to(
      contain_exactly(
        "index.html",
        "en/index.html",
        "en/licenses/index.html",
        "en/privacy/index.html",
        "en/terms/index.html",
        "ru/index.html",
        "ru/licenses/index.html",
        "ru/privacy/index.html",
        "ru/terms/index.html",
        "licenses/index.html",
        "privacy/index.html",
        "terms/index.html"
      )
    )
  end

  it "renders each locale in its own language" do
    expect(page("en", "index.html")).to(match(/<html[^>]*lang="en"/))
    expect(page("ru", "index.html")).to(match(/<html[^>]*lang="ru"/))
  end

  it "keeps nothing that only a Rails request can satisfy" do
    html = page("en", "index.html")

    expect(html).not_to(include("csrf-token"))
    expect(html).not_to(include("csp-nonce"))
    expect(html).not_to(include("importmap"))
    expect(html).not_to(include("rel=\"manifest\""))
  end

  it "sends app links to the app and keeps its own pages local" do
    html = page("en", "index.html")

    expect(html).to(include("href=\"#{app_url}/en/login\""))
    expect(html).to(include("href=\"/en/licenses\""))
    expect(html).not_to(include("href=\"#{app_url}/en/licenses\""))
  end

  it "points the russian pages at their own canonical url" do
    expect(page("ru", "index.html")).to(
      match(%r{rel="canonical"[^>]*href="[^"]*/ru/"|href="[^"]*/ru/"[^>]*rel="canonical"})
    )
  end

  it "offers each page in both languages to search engines, and names a default" do
    html = page("en", "index.html")

    expect(html.scan("rel=\"alternate\"").length).to(eq(I18n.available_locales.length + 1))
    I18n.available_locales.each do |locale|
      expect(html).to(include("hreflang=\"#{locale}\" href=\"#{site_url}/#{locale}/\""))
    end

    expect(html).to(include("hreflang=\"x-default\" href=\"#{site_url}/en/\""))
  end

  it "copies every stylesheet the pages ask for" do
    asked = page("en", "index.html").scan(%r{href="(/assets/[^"]+)"}).flatten

    expect(asked).not_to(be_empty)
    asked.each { |path| expect(root.join(path.delete_prefix("/"))).to(exist) }
  end

  it "lists both languages of the landing in the sitemap and points robots at it" do
    xml = root.join("sitemap.xml").read

    expect(xml).to(include("<loc>#{site_url}/en/</loc>"))
    expect(xml).to(include("<loc>#{site_url}/ru/</loc>"))
    expect(xml).to(include("hreflang=\"ru\" href=\"#{site_url}/ru/\""))
    expect(xml.scan("<loc>").length).to(eq(Site::Exporter::PAGES.size * I18n.available_locales.size))
    expect(root.join("robots.txt").read).to(include("Sitemap: #{site_url}/sitemap.xml"))
  end

  it "keeps the bare root alive and sends it on to a language" do
    html = page("index.html")

    expect(html).to(include("url=/en/"))
    expect(html).to(include("rel=\"canonical\" href=\"#{site_url}/en/\""))
    expect(html).to(include("navigator.language"))
  end

  it "still opens the menus and runs the search once Stimulus is gone" do
    html = page("en", "licenses", "index.html")

    expect(html).to(include("data-menu-target=panel"))
    expect(html).to(include("data-search-url-value=\"#{app_url}/en/search\""))
    expect(html).not_to(include("data-search-url-value=\"/en/search\""))
  end

  it "leaves no form that needs a server to answer it" do
    root.glob("**/*.html").each { |page| expect(page.read).not_to(include("method=\"post\"")) }
  end

  it "switches language on the landing only" do
    expect(page("en", "index.html")).to(include("href=\"/ru/\""))
    expect(page("ru", "index.html")).to(include("href=\"/en/\""))
  end

  it "reads the legal pages in the language the visitor arrived in" do
    %w[licenses privacy terms].each do |name|
      expect(page("en", name, "index.html")).to(match(/<html[^>]*lang="en"/))
      expect(page("ru", name, "index.html")).to(match(/<html[^>]*lang="ru"/))
    end

    expect(page("ru", "terms", "index.html")).to(include(I18n.t("terms.title", locale: :ru)))
    expect(page("ru", "privacy", "index.html")).to(include(I18n.t("privacy.contact.heading", locale: :ru)))
  end

  it "points an old bare legal address at the english page as the canonical one" do
    %w[licenses privacy terms].each do |name|
      html = page(name, "index.html")

      expect(html).to(eq(page("en", name, "index.html")))
      expect(html).to(
        match(%r{rel="canonical"[^>]*href="#{site_url}/en/#{name}"|href="#{site_url}/en/#{name}"[^>]*rel="canonical"})
      )
      expect(html).to(include("hreflang=\"ru\" href=\"#{site_url}/ru/#{name}\""))
    end
  end

  it "loads the heavy brush face from the address the app uses too" do
    expect(page("en", "index.html")).to(include("data-kai-font-url-value=\"#{FontAssets.kai_full_url}\""))
  end

  it "opens the connections and preloads the face the page paints with" do
    html = page("en", "index.html")

    expect(html).to(include("rel=\"preconnect\" href=\"#{app_url}\""))
    expect(html).to(include("rel=\"preload\" as=\"font\""))
    expect(html).to(include(FontAssets.url_for(FontAssets::KAI_CORE)))
  end

  it "gives the legal pages a way back to the landing" do
    expect(page("privacy", "index.html")).to(include("TaiwanCards"))
  end

  it "keeps no font of its own once a shared origin serves them" do
    expect(root.glob("assets/*.css").map(&:read).join).not_to(match(%r{url\("/fonts/}))
    expect(root.join("fonts")).not_to(exist)
  end

  it "asks for fonts at the same address the app asks for them" do
    expect(root.glob("assets/*.css").map(&:read).join).to(include(FontAssets.url_for(FontAssets::KAI_CORE)))
  end

  it "bakes the counts in rather than leaving them to a server" do
    expect(page("en", "index.html")).to(
      include(ActiveSupport::NumberHelper.number_to_delimited(Lexeme.unrestricted.where(kind: :character).count))
    )
  end
end
