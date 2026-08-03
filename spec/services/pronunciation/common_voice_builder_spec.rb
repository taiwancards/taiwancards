# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Corpus::CommonVoiceBuilder do
  let(:base) { Dir.mktmpdir }
  let(:archive) { Dir.mktmpdir }
  let(:locale) { described_class::LOCALE }

  after do
    FileUtils.rm_rf(base)
    FileUtils.rm_rf(archive)
    link = File.join(Pronunciation::TemplateStore.instance.root, described_class::DIR)
    FileUtils.rm(link) if File.symlink?(link) && File.readlink(link).include?(base)
  end

  def release(rows)
    dir = File.join(archive, "cv-corpus-99.0", locale)
    FileUtils.mkdir_p(File.join(dir, "clips"))
    header = %w[client_id path sentence age gender accents]
    File.write(
      File.join(dir, "validated.tsv"),
      ([header] + rows.map { |row| header.map { |key| row[key] } }).map { |cells| cells.join("\t") }.join("\n")
    )
    rows.each { |row| tone(File.join(dir, "clips", row["path"])) }
    dir
  end

  def tone(path, rate: 16_000)
    frames = Array.new(rate / 2) { |i| [(Math.sin(2 * Math::PI * 220 * i / rate.to_f) * 12_000).round].pack("s<") }
    body = frames.join
    header = ["RIFF", 36 + body.bytesize, "WAVE", "fmt ", 16, 1, 1, rate, rate * 2, 2, 16, "data", body.bytesize].pack(
      "a4Va4a4VvvVVvva4V"
    )
    File.binwrite(path, header + body)
  end

  def manifest = JSON.parse(File.read(File.join(base, described_class::DIR, "manifest.json")))

  it "takes only the clips it asked for out of a shard" do
    tar = File.join(archive, "shard.tar")
    File.open(tar, "wb") do |io|
      Gem::Package::TarWriter.new(io) do |writer|
        %w[one.wav two.wav].each do |name|
          source = File.join(archive, name)
          tone(source)
          writer.add_file("clips/#{name}", 0o644) { |file| file.write(File.binread(source)) }
        end
      end
    end

    builder = described_class.new(base: base)
    allow(builder).to(receive(:shards).and_return(["shard.tar"]))
    allow(builder).to(receive(:download).and_return(tar))
    allow(builder).to(
      receive(:rows).and_return(
        [
          {
            "client_id" => "a",
            "path" => "one.wav",
            "sentence" => "你好",
            "accents" => "出生地：臺北市",
            "_bucket" => "train"
          }
        ]
      )
    )

    builder.build!
    audio = File.join(base, described_class::DIR, "audio")

    expect(File.exist?(File.join(audio, "one.wav"))).to(be(true))
    expect(File.exist?(File.join(audio, "two.wav"))).to(be(false))
  end

  it "skips sentences too long to split into syllables" do
    long = "一二三四五六七八九十"
    release(
      [
        {"client_id" => "a", "path" => "one.wav", "sentence" => "你好", "accents" => "出生地：臺北市"},
        {"client_id" => "a", "path" => "two.wav", "sentence" => long, "accents" => "出生地：臺北市"}
      ]
    )

    described_class.new(archive: archive, base: base).build!

    expect(manifest["clips"].keys).to(contain_exactly("one.wav"))
    expect(File.exist?(File.join(base, described_class::DIR, "audio", "two.wav"))).to(be(false))
  end

  it "keeps only speakers who declared a birthplace" do
    release(
      [
        {"client_id" => "a", "path" => "one.wav", "sentence" => "你好", "accents" => "出生地：臺北市"},
        {"client_id" => "b", "path" => "two.wav", "sentence" => "早安", "accents" => ""}
      ]
    )

    described_class.new(archive: archive, base: base).build!

    expect(manifest["clips"].keys).to(contain_exactly("one.wav"))
    expect(manifest["n_speakers"]).to(eq(1))
  end

  it "records where each clip came from and who said it" do
    release(
      [
        {
          "client_id" => "a",
          "path" => "one.wav",
          "sentence" => "你好",
          "accents" => "出生地：高雄市",
          "gender" => "male_masculine"
        }
      ]
    )

    described_class.new(archive: archive, base: base).build!
    clip = manifest["clips"].fetch("one.wav")

    expect(clip).to(include("speaker" => "a", "sentence" => "你好", "gender" => "male_masculine"))
    expect(clip["path"]).to(eq("data/#{described_class::DIR}/audio/one.wav"))
    expect(File.exist?(File.join(base, described_class::DIR, "audio", "one.wav"))).to(be(true))
  end

  it "converts every clip to the sample rate the analyser expects" do
    release([{"client_id" => "a", "path" => "one.wav", "sentence" => "你好", "accents" => "出生地：臺南市"}])

    described_class.new(archive: archive, base: base).build!
    signal = DSP.read(File.join(base, described_class::DIR, "audio", "one.wav"))

    expect(signal.sample_rate).to(eq(described_class::RATE))
    expect(manifest["sample_rate"]).to(eq(described_class::RATE))
  end

  it "leaves clips it already converted alone" do
    release([{"client_id" => "a", "path" => "one.wav", "sentence" => "你好", "accents" => "出生地：臺中市"}])

    described_class.new(archive: archive, base: base).build!
    first = described_class.new(archive: archive, base: base).build!

    expect(first[:converted]).to(eq(0))
    expect(first[:clips]).to(eq(1))
  end
end
