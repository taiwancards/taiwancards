# frozen_string_literal: true

require "rails_helper"

RSpec.describe Locales do
  describe ".guess" do
    it "takes German from a German-speaking country when the browser names only English or nothing" do
      %w[DE AT CH LI LU].each do |country|
        expect(described_class.guess(header: "en-US,en;q=0.9", country:)).to(eq("de"), country)
        expect(described_class.guess(header: nil, country:)).to(eq("de"), country)
        expect(described_class.guess(header: "", country: country.downcase)).to(eq("de"), country)
      end
    end

    it "does not take German from a multilingual country whose other language the browser names" do
      expect(described_class.guess(header: "fr-CH,fr;q=0.9,en;q=0.8", country: "CH")).to(eq("en"))
      expect(described_class.guess(header: "it-CH", country: "CH")).to(eq("en"))
      expect(described_class.guess(header: "rm-CH,en;q=0.5", country: "CH")).to(eq("en"))
      expect(described_class.guess(header: "fr-LU", country: "LU")).to(eq("en"))
    end

    it "keeps the country guess where the vetoing language belongs to another country" do
      expect(described_class.guess(header: "fr-FR,en;q=0.8", country: "AT")).to(eq("de"))
      expect(described_class.guess(header: "it-IT", country: "LU")).to(eq("de"))
    end

    it "lets a browser that names German win anywhere" do
      expect(described_class.guess(header: "de-DE", country: "FR")).to(eq("de"))
      expect(described_class.guess(header: "fr-CH,de-CH;q=0.9", country: "CH")).to(eq("de"))
    end

    it "keeps the Vietnamese and Russian guesses as they were" do
      expect(described_class.guess(header: "en-US,en;q=0.9", country: "VN")).to(eq("vi"))
      expect(described_class.guess(header: "uk-UA,uk;q=0.9,en;q=0.8", country: "UA")).to(eq("ru"))
      expect(described_class.guess(header: nil, country: "KZ")).to(eq("ru"))
      expect(described_class.guess(header: "ru-RU", country: "VN")).to(eq("ru"))
      expect(described_class.guess(header: "en-US", country: "TW")).to(eq("en"))
    end
  end

  describe ".resolve" do
    it "lets the address and then the stored choice beat the country" do
      expect(described_class.resolve(url: "en", stored: "ru", header: "de-DE", country: "DE")).to(eq("en"))
      expect(described_class.resolve(url: nil, stored: "ru", header: "de-DE", country: "DE")).to(eq("ru"))
      expect(described_class.resolve(url: "de", stored: "ru", country: "VN")).to(eq("de"))
    end
  end

  describe ".key and .pick" do
    it "stores Indonesian under ind so it never meets an identifier" do
      expect(described_class.key("id")).to(eq("ind"))
      expect(described_class.key(:id)).to(eq("ind"))
      expect(described_class::STORED).to(eq(%w[en ru vi de ind]))
      expect(described_class::ALL.map { |code| described_class.key(code) }).to(eq(described_class::STORED))
    end

    it "keeps every other locale code as its own storage key" do
      %w[en ru vi de].each { |code| expect(described_class.key(code)).to(eq(code)) }
    end

    it "reads Indonesian from ind, not from a row's identifier" do
      row = {"id" => 7, "en" => "x", "ind" => "y"}

      expect(described_class.pick(row, "id")).to(eq("y"))
      expect(described_class.pick(row, :id)).to(eq("y"))
      expect(described_class.pick(row.except("ind"), "id")).to(eq("x"))
      expect(described_class.pick(row, "de")).to(eq("x"))
    end

    it "reads the current locale when none is given" do
      I18n.with_locale(:id) do
        expect(described_class.key).to(eq("ind"))
        expect(described_class.pick({"en" => "x", "ind" => "y"})).to(eq("y"))
      end
    end
  end

  describe "Indonesian" do
    it "takes Indonesian from Indonesia when the browser names only English or nothing" do
      expect(described_class.guess(header: "en-US,en;q=0.9", country: "ID")).to(eq("id"))
      expect(described_class.guess(header: nil, country: "id")).to(eq("id"))
    end

    it "hears Indonesian in both the current and the legacy language tag" do
      expect(described_class.guess(header: "id-ID,id;q=0.9,en;q=0.8", country: "SG")).to(eq("id"))
      expect(described_class.guess(header: "in", country: "TW")).to(eq("id"))
      expect(described_class.guess(header: "in-ID,en;q=0.5")).to(eq("id"))
      expect(described_class.from_header("id-ID")).to(eq("id"))
    end

    it "links Indonesian to its Open Graph locale and its URL prefix" do
      expect(described_class.known?("id")).to(be(true))
      expect(described_class::OPEN_GRAPH.fetch("id")).to(eq("id_ID"))
      expect(described_class.prefix("/id/grammar")).to(eq("id"))
      expect(described_class.strip("/id/grammar")).to(eq("/grammar"))
      expect(described_class.compares_china?("id")).to(be(true))
    end
  end

  it "knows German, links it to its Open Graph locale and lets it compare with China" do
    expect(described_class.known?("de")).to(be(true))
    expect(described_class::OPEN_GRAPH.fetch("de")).to(eq("de_DE"))
    expect(described_class.compares_china?("de")).to(be(true))
    expect(described_class.serves?("/variants", "de")).to(be(true))
  end
end
