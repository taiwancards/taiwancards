# frozen_string_literal: true

require "rails_helper"

RSpec.describe FontAssets do
  around do |example|
    Dir.mktmpdir do |workspace|
      fonts = Pathname(workspace).join("fonts")
      fonts.mkpath
      fonts.join("tw-kai-core-1a2b3c4d.woff2").binwrite("core face")
      fonts.join("tw-kai-01-9f8e7d6c.woff2").binwrite("first slice")
      ENV["FONT_DIR"] = fonts.to_s
      example.run
    ensure
      ENV.delete("FONT_DIR")
      described_class.forget_stamps!
    end
  end

  def with_base(url)
    allow(ENV).to(receive(:[]).and_call_original)
    allow(ENV).to(receive(:[]).with("ASSETS_BASE_URL").and_return(url))
    described_class.forget_stamps!
  end

  it "serves fonts from the app itself when no shared origin is configured" do
    with_base(nil)

    expect(described_class.kai_core_url).to(eq("/fonts/tw-kai-core-1a2b3c4d.woff2"))
  end

  it "sends both sites to the same origin when one is configured" do
    with_base("https://fonts.example.test")

    expect(described_class.kai_core_url).to(start_with("https://fonts.example.test/fonts/tw-kai-core-1a2b3c4d.woff2"))
  end

  it "stamps the url with the contents so a replaced file is not served from cache" do
    with_base("https://fonts.example.test")

    stamp = described_class.kai_core_url[/\?v=(\w+)/, 1]

    expect(stamp).to(eq(Digest::SHA256.file(described_class.kai_core).hexdigest[0, 8]))
  end

  it "gives the same url every time so the cache entry is reused" do
    with_base("https://fonts.example.test")

    expect(described_class.kai_core_url).to(eq(described_class.kai_core_url))
  end

  it "finds the core face by its prefix whatever its content hash is" do
    expect(described_class.kai_faces.map { |file| file.basename.to_s }).to(
      eq(%w[tw-kai-core-1a2b3c4d.woff2 tw-kai-01-9f8e7d6c.woff2])
    )
    expect(described_class.kai_installed?).to(be(true))
  end

  it "reports nothing to preload when the fonts are not installed" do
    described_class.kai_faces.each(&:delete)

    expect(described_class.kai_core).to(be_nil)
    expect(described_class.kai_core_url).to(be_nil)
    expect(described_class.kai_installed?).to(be(false))
  end

  it "leaves the stamp off a file it cannot find" do
    with_base("https://fonts.example.test")

    expect(described_class.url_for("nothing-here.woff2")).to(eq("https://fonts.example.test/fonts/nothing-here.woff2"))
  end
end
