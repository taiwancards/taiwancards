# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PWA", :no_auth do
  def manifest(locale = nil, headers: {})
    raw_get(locale ? "/manifest?locale=#{locale}" : "/manifest", headers:)
    JSON.parse(response.body)
  end

  def png_size(path)
    header = Rails.public_path.join(path.delete_prefix("/")).binread(24)
    header.unpack("@16NN").join("x")
  end

  it "describes an installable standalone app with a stable identity" do
    body = manifest

    expect(body).to(
      include(
        "id" => "/",
        "name" => "TaiwanCards",
        "short_name" => "TaiwanCards",
        "description" => I18n.t("meta.description", locale: :en),
        "lang" => "en",
        "start_url" => "/en/desk",
        "scope" => "/",
        "display" => "standalone",
        "theme_color" => "#ffffff",
        "background_color" => "#ffffff"
      )
    )
    expect(body["categories"]).to(include("education"))
  end

  it "speaks the language named in its address and keeps one identity across languages" do
    body = manifest("vi")

    expect(body["lang"]).to(eq("vi"))
    expect(body["id"]).to(eq("/"))
    expect(body["start_url"]).to(eq("/vi/desk"))
    expect(body["description"]).to(eq(I18n.t("meta.description", locale: :vi)))
    expect(body["shortcuts"].map { it["name"] }).to(
      eq(%w[exams dict reader study].map { I18n.t("nav.#{it}", locale: :vi) })
    )
    expect(body["shortcuts"].map { it["url"] }).to(eq(%w[/vi/exams /vi/dict /vi/reader /vi/study]))
  end

  it "answers from the address alone so a shared cache can hold it" do
    body = manifest(headers: {"Accept-Language" => "ru", "Cookie" => "locale=vi"})

    expect(body["lang"]).to(eq("en"))
    expect(response.media_type).to(eq("application/manifest+json"))
    expect(response.headers["cache-control"]).to(include("public", "max-age=3600"))
    expect(response.headers["Set-Cookie"]).to(be_blank)
  end

  it "falls back to English for a language the app does not have" do
    expect(manifest("xx")["lang"]).to(eq("en"))
  end

  it "ships any and maskable icons at 192 and 512 that exist at the declared size" do
    icons = manifest.fetch("icons").select { it["type"] == "image/png" }

    %w[any maskable].each do |purpose|
      expect(icons.select { it["purpose"] == purpose }.map { it["sizes"] }).to(contain_exactly("192x192", "512x512"))
    end

    icons.each { expect(png_size(it["src"])).to(eq(it["sizes"])) }
  end

  it "points every shortcut at a real page with an icon of the declared size" do
    manifest.fetch("shortcuts").each do |shortcut|
      expect(Rails.application.routes.recognize_path(shortcut["url"])).to(be_present)
      shortcut["icons"].each { expect(png_size(it["src"])).to(eq(it["sizes"])) }
    end
  end

  it "lists phone and desktop screenshots that exist at the declared size" do
    shots = manifest.fetch("screenshots")

    expect(shots.map { it["form_factor"] }.uniq).to(contain_exactly("narrow", "wide"))
    shots.each do |shot|
      expect(png_size(shot["src"])).to(eq(shot["sizes"]))
      expect(shot["label"]).to(be_present)
    end
  end

  it "is linked from the layout in the page's language" do
    get("/vi/offline")

    expect(response.body).to(include("<link href=\"/manifest?locale=vi\" rel=\"manifest\""))
  end
end
