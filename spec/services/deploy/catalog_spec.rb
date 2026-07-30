# frozen_string_literal: true

require "rails_helper"

RSpec.describe Deploy::Catalog do
  it "covers every directory the application reads at runtime" do
    expect(described_class.all.map(&:id)).to(
      include("huayu", "pronunciation", "textbook", "dictionaries", "moe_audio", "moe_audio_words")
    )
  end

  it "ships pronunciation to the path the store reads from" do
    section = described_class.find("pronunciation")

    expect(File.join("/var/data", section.to)).to(eq(Pronunciation::TemplateStore::DEFAULT_PATH))
    expect(section.only).to(match_array(Pronunciation::Sync::PAYLOAD))
  end

  it "swaps pronunciation in one piece instead of file by file" do
    expect(described_class.find("pronunciation").mode).to(eq(:atomic))
  end

  it "is the only place the full transfer script gets its sections from" do
    script = Rails.root.join("bin/rebuild-data-render.sh").read

    expect(script).to(include("Deploy::Catalog.plan"))
    expect(script).not_to(match(/^SECTIONS="/))
  end

  it "ships every huayu file the application names anywhere in its code" do
    named = Dir
      .glob(Rails.root.join("app/**/*.rb"))
      .flat_map { |file| File.read(file).scan(%r{"(huayu/[\w./-]+)"}).flatten }
      .uniq
      .map { |path| Rails.root.join("data", path) }
      .select(&:exist?)

    shipped = described_class.find("huayu").files.map(&:to_s)

    expect(named.length).to(be > 20)
    expect(named.map(&:to_s) - shipped).to(be_empty)
  end

  it "ships the file deploy:sync reads before it imports the sources" do
    section = described_class.find("manifests")

    expect(section.only).to(include("content_sources.json"))
    expect(File.join("/var/data", section.to, "content_sources.json")).to(eq("/var/data/content_sources.json"))
  end

  it "ships the whole font directory, because fonts:install cannot download the built faces" do
    section = described_class.find("fonts")
    skip("storage/fonts is not in this checkout") unless section.exist?

    manifest = JSON.parse(AppData.path("fonts.json").read).keys
    built = FontAssets.kai_faces.map { |face| face.basename.to_s }

    expect(built).to(all(satisfy { |face| manifest.exclude?(face) }))
    expect(section.files.map { |file| file.basename.to_s }).to(include(*built))
  end

  it "sends audio and fonts uncompressed and everything else compressed" do
    plain = described_class.all.reject(&:compress?).map(&:id)

    expect(plain).to(match_array(%w[fonts textbook_audio]))
  end

  describe ".plan" do
    it "gives the shell one tab separated row per section" do
      rows = described_class.plan

      expect(rows.length).to(eq(described_class.all.length))
      expect(rows).to(all(satisfy { |row| row.count("\t") == 4 }))
    end

    it "names the disk root as a dot so the shell can join paths" do
      row = described_class.plan(described_class.select(only: "manifests")).first

      expect(row.split("\t")).to(eq(["manifests", "data", ".", "gzip", "content_sources.json fonts.json"]))
    end

    it "asks for a whole directory when the section is not limited" do
      row = described_class.plan(described_class.select(only: "textbook")).first

      expect(row.split("\t").last).to(eq("."))
    end
  end

  describe ".select" do
    it "returns everything by default" do
      expect(described_class.select.length).to(eq(described_class.all.length))
    end

    it "narrows to ONLY" do
      expect(described_class.select(only: "huayu,pronunciation").map(&:id)).to(eq(%w[huayu pronunciation]))
    end

    it "drops SKIP" do
      expect(described_class.select(skip: "moe_audio_words").map(&:id)).not_to(include("moe_audio_words"))
    end

    it "refuses an unknown section rather than shipping nothing" do
      expect { described_class.select(only: "pronounciation") }.to(raise_error(ArgumentError, /pronounciation/))
    end
  end

  describe "a section limited by only" do
    let(:section) { described_class.find("pronunciation") }

    it "counts just the listed entries" do
      skip("data/pronunciation is not in this checkout") unless section.source.exist?

      whole = section.source.glob("**/*").select(&:file?).sum(&:size)
      expect(section.bytes).to(be < whole)
    end

    it "hands rsync the entries themselves, not the whole directory" do
      skip("data/pronunciation is not in this checkout") unless section.source.exist?

      expect(section.sync_sources).to(all(satisfy { |path| !path.end_with?("/") }))
      expect(section.sync_sources.length).to(eq(section.paths.length))
    end
  end

  describe "a whole-directory section" do
    it "hands rsync the trailing slash form" do
      section = described_class.find("textbook")
      skip("data/textbook is not in this checkout") unless section.exist?

      expect(section.sync_sources).to(eq(["#{section.source}/"]))
    end
  end
end
