# frozen_string_literal: true

require "rails_helper"

RSpec.describe JsonData do
  let(:root) { Pathname(Dir.mktmpdir) }
  let(:path) { root.join("sample.json") }

  before { allow(AppData).to(receive(:path).with("sample.json").and_return(path)) }

  after { FileUtils.remove_entry(root) }

  it "reads the file once and hands back the same object afterwards" do
    path.write(JSON.generate({"a" => 1}))
    data = described_class.new("sample.json")

    expect(data.value).to(eq({"a" => 1}))
    expect(data.value).to(be(data.value))
  end

  it "falls back to the default when the file is not there at all" do
    data = described_class.new("sample.json", default: {"terms" => {}})

    expect(data.value).to(eq({"terms" => {}}))
    expect(data.exist?).to(be(false))
  end

  it "falls back to the default rather than raising on a broken file" do
    path.write("{ not json")
    data = described_class.new("sample.json", default: [])

    expect(data.value).to(eq([]))
  end

  it "hands out a copy, so a caller cannot spoil the default for everyone else" do
    fallback = {"terms" => {}}
    data = described_class.new("sample.json", default: fallback)

    data.value["mine"] = true

    expect(fallback).to(eq({"terms" => {}}))
    expect(described_class.new("sample.json", default: fallback).value).to(eq({"terms" => {}}))
  end

  it "keeps serving the old contents until it is told to forget them" do
    path.write(JSON.generate({"a" => 1}))
    data = described_class.new("sample.json")
    data.value

    path.write(JSON.generate({"a" => 2}))

    expect(data.value).to(eq({"a" => 1}))
    data.reset!
    expect(data.value).to(eq({"a" => 2}))
  end

  it "picks up an edited file on its own when asked to watch it" do
    path.write(JSON.generate({"a" => 1}))
    data = described_class.new("sample.json", watch: true)
    data.value

    path.write(JSON.generate({"a" => 2}))
    later = 1.minute.from_now.to_time
    File.utime(later, later, path)

    expect(data.value).to(eq({"a" => 2}))
  end

  it "reads from the media root when told to" do
    media = root.join("clip.json")
    media.write(JSON.generate({"clips" => []}))
    allow(AppData).to(receive(:media_path).with("clip.json").and_return(media))

    expect(described_class.new("clip.json", root: :media).value).to(eq({"clips" => []}))
  end
end
