# frozen_string_literal: true

require "rails_helper"

RSpec.describe PrecompressedAssets do
  let(:directory) { Pathname.new(Dir.mktmpdir) }
  let(:stylesheet) { ".card { color: red; }\n" * 200 }

  after { FileUtils.remove_entry(directory) }

  def asset(name, content)
    path = directory.join(name)
    FileUtils.mkdir_p(path.dirname)
    path.binwrite(content)
    path
  end

  it "writes a brotli copy beside every stylesheet, script and svg, nested ones included" do
    asset("tailwind-abc123.css", stylesheet)
    asset("controllers/card-def456.js", "export default {}\n" * 200)
    asset("icon-789abc.svg", "<svg><path d=\"M0 0\"/></svg>\n" * 200)

    expect(described_class.write(directory)).to(eq(3))
    expect(Brotli.inflate(directory.join("tailwind-abc123.css.br").binread)).to(eq(stylesheet))
    expect(directory.join("controllers/card-def456.js.br")).to(exist)
    expect(directory.join("icon-789abc.svg.br")).to(exist)
  end

  it "leaves formats that are already compressed or never served precompressed alone" do
    asset("tw-kai-core-abc123.woff2", "x" * 4096)
    asset("og-abc123.png", "x" * 4096)
    asset("manifest.json", "{}" * 2048)

    expect(described_class.write(directory)).to(eq(0))
    expect(directory.glob("*.br")).to(be_empty)
  end

  it "keeps a copy it already wrote, since digested names never change content" do
    asset("tailwind-abc123.css", stylesheet)
    copy = asset("tailwind-abc123.css.br", "earlier")

    expect(described_class.write(directory)).to(eq(0))
    expect(copy.binread).to(eq("earlier"))
  end

  it "skips a file brotli cannot make smaller" do
    asset("tiny-abc123.js", "a")

    expect(described_class.write(directory)).to(eq(0))
    expect(directory.join("tiny-abc123.js.br")).not_to(exist)
  end
end
