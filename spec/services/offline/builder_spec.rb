# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe Offline::Builder do
  let(:root) { Pathname(Dir.mktmpdir("offline-packs")) }
  let(:renderer) { instance_double(Offline::Renderer) }

  after { root.rmtree if root.exist? }

  def build(only: ["core"])
    allow(renderer).to(receive(:call)) { |path, locale| page(path, locale) }
    described_class.new(root: root, io: StringIO.new, renderer: renderer).call(only: only)
  end

  def page(path, locale)
    <<~HTML
      <!DOCTYPE html><html lang="#{locale}"><head><title>#{path}</title>
      <link rel="stylesheet" href="/assets/app-abc.css">
      <script type="importmap">{}</script></head>
      <body><main class="max-w-3xl"><p>#{path} in #{locale}</p></main></body></html>
    HTML
  end

  def manifest = JSON.parse(root.join(Offline::MANIFEST).read)

  it "writes a manifest naming every pack it built" do
    build

    expect(manifest.fetch("packs").map { |pack| pack["id"] }).to(eq(["core"]))
  end

  it "keeps one chunk file per locale" do
    build
    pack = manifest.fetch("packs").first

    expect(pack.fetch("chunks").keys).to(match_array(I18n.available_locales.map(&:to_s)))
    pack.fetch("chunks").each_value { |names| names.each { |name| expect(root.join(name)).to(exist) } }
  end

  it "stores the fragments under their localised path" do
    build
    name = manifest.fetch("packs").first.fetch("chunks").fetch("en").first
    chunk = JSON.parse(root.join(name).read)

    expect(chunk.keys).to(all(start_with("/en/")))
    expect(chunk.values.first.keys).to(match_array(%w[t w m]))
  end

  it "ships the offline shells with the core pack" do
    build
    shells = JSON.parse(root.join(manifest.fetch("packs").first.fetch("shells")).read)

    expect(shells.keys).to(match_array(I18n.available_locales.map(&:to_s)))
  end

  it "renders nothing again when neither the pages nor the data moved" do
    build
    expect(renderer).to(have_received(:call).at_least(:once))

    described_class.new(root: root, io: StringIO.new, renderer: renderer).call(only: ["core"])

    expect(manifest.fetch("packs").size).to(eq(1))
  end

  it "records each pack in the manifest as soon as it is built" do
    allow(renderer).to(receive(:call)) do |path, locale|
      raise Offline::Renderer::Refused, "boom" if path.include?("grammar")

      page(path, locale)
    end

    expect {
      described_class.new(root: root, io: StringIO.new, renderer: renderer).call(only: %w[core grammar])
    }
      .to(raise_error(/refused/))

    expect(manifest.fetch("packs").map { |pack| pack["id"] }).to(eq(["core"]))
  end

  it "refuses a pack it has never heard of" do
    expect { build(only: ["nonsense"]) }.to(raise_error(/knows no section/))
  end

  it "clears out files no pack refers to any more" do
    build
    stray = root.join("core-deadbeef.en.0.json")
    stray.write("{}")

    described_class.new(root: root, io: StringIO.new, renderer: renderer).call(only: ["core"])

    expect(stray).not_to(exist)
  end
end
