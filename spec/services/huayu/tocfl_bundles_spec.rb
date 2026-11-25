# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::TocflBundles do
  let(:fixtures) { Rails.root.join("spec/fixtures/files/tocfl_bundles") }
  let(:source) { Pathname(Dir.mktmpdir).join("bundles") }

  before { FileUtils.cp_r(fixtures, source) }

  after do
    FileUtils.rm_rf(source.dirname)
    described_class.reset!
  end

  it "summarizes each bundle with the parts, plays, clips and scale the pages need" do
    row = described_class.build(source:).fetch("a-set1-listening")

    expect(row).to(include("minutes" => 60, "count" => 3, "levels" => ["Level 1", "Level 2"]))
    expect(row["clips"]).to(
      eq(
        %w[
          mock_BandA_mp3_en/001.mp3
          mock_BandA_mp3_en/002.mp3
          mock_BandA_mp3_en/003.mp3
          mock_BandA_mp3_en/004.mp3
          mock_BandA_mp3_en/005.mp3
          mock_BandA_mp3_vie/001.mp3
          mock_BandA_mp3_vie/009.mp3
          mock_BandA_mp3_vie/007.mp3
        ]
      )
    )
    expect(row["parts"]).to(
      eq(
        [
          {"id" => 1, "title" => "看圖回答", "count" => 1, "plays" => 2},
          {"id" => 4, "title" => "短文理解", "count" => 2, "plays" => 1}
        ]
      )
    )
    expect(row["scale"]["max"]).to(eq(80))
  end

  it "changes the digest when any file of the bundle changes, so the edge never serves a stale paper" do
    before = described_class.build(source:).dig("a-set1-listening", "digest")
    expect(described_class.build(source:).dig("a-set1-listening", "digest")).to(eq(before))

    source.join("a-set1-listening/img/q01.webp").binwrite("changed")

    expect(described_class.build(source:).dig("a-set1-listening", "digest")).not_to(eq(before))
  end

  it "writes the manifest and serves versioned addresses from it" do
    target = source.dirname.join("huayu/tocfl_bundles.json")
    described_class.write!(source:, target:)
    allow(described_class::MANIFEST).to(receive(:value).and_return(JSON.parse(target.read)))
    described_class.reset!

    bundle = described_class.find("a-set1-listening")

    expect(described_class.available?("a-set1-reading")).to(be(false))
    expect(described_class.bundle_url(bundle)).to(
      end_with("/tocfl_papers/a-set1-listening/bundle.json?v=#{bundle.digest}")
    )
    expect(bundle.parts.map(&:plays)).to(eq([2, 1]))
  end

  it "converts a raw score on the official table and names the level it reaches" do
    allow(described_class::MANIFEST).to(receive(:value).and_return({"bundles" => described_class.build(source:)}))
    described_class.reset!
    bundle = described_class.find("a-set1-listening")

    expect([0, 1, 2, 3].map { |raw| bundle.scaled(raw) }).to(eq([0, 30, 60, 80]))
    expect(bundle.level_for(30)).to(be_nil)
    expect(bundle.level_for(60)).to(eq("Level 2"))
  end

  it "fills missing level cut-offs from the published pass marks, naming their source, and lists the paper files" do
    published = [{"level" => "Level 1", "min" => 41}, {"level" => "Level 2", "min" => 60}]
    allow(described_class::LEVELS).to(
      receive(:value).and_return(
        {
          "source" => {"title" => "brochure"},
          "thresholds" => {"listening" => {"A" => published}}
        }
      )
    )
    source.join("a-set1-listening/bundle.json").then do |file|
      file.write(JSON.generate(JSON.parse(file.read).tap { |bundle| bundle["scale"]["thresholds"] = nil }))
    end

    row = described_class.build(source:).fetch("a-set1-listening")

    expect(row["scale"]).to(include("thresholds" => published, "thresholds_source" => "brochure"))
    expect(row["papers"]).to(eq("en" => "ls.pdf", "vi" => "ls_vie.pdf"))
  end

  it "reports where the bundle's key disagrees with the paper key the server marks with" do
    expect(described_class.key_conflicts(source:)).to(eq(["a-set1-listening #3: bundle Z, paper key B"]))
  end

  it "reports clips the bundle names but the media folder lacks" do
    audio = source.dirname.join("media")
    audio.join("mock_BandA_mp3_en").mkpath
    %w[001.mp3 002.mp3 003.mp3].each { |name| audio.join("mock_BandA_mp3_en", name).write("") }

    expect(described_class.missing_audio(source:, root: audio)).to(
      eq(
        %w[
          mock_BandA_mp3_en/004.mp3
          mock_BandA_mp3_en/005.mp3
          mock_BandA_mp3_vie/001.mp3
          mock_BandA_mp3_vie/009.mp3
          mock_BandA_mp3_vie/007.mp3
        ]
          .map { |path| "a-set1-listening: #{path}" }
      )
    )
  end
end
