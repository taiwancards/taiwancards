# frozen_string_literal: true

require "rails_helper"

RSpec.describe FontAssets do
  after { described_class.forget_stamps! }

  def with_base(url)
    allow(ENV).to(receive(:[]).and_call_original)
    allow(ENV).to(receive(:[]).with("ASSETS_BASE_URL").and_return(url))
    described_class.forget_stamps!
  end

  it "serves fonts from the app itself when no shared origin is configured" do
    with_base(nil)

    expect(described_class.kai_core_url).to(eq("/fonts/#{described_class::KAI_CORE}"))
  end

  it "sends both sites to the same origin when one is configured" do
    with_base("https://fonts.example.test")

    expect(described_class.kai_core_url).to(start_with("https://fonts.example.test/fonts/#{described_class::KAI_CORE}"))
  end

  it "stamps the url with the contents so a replaced file is not served from cache" do
    with_base("https://fonts.example.test")

    stamp = described_class.kai_core_url[/\?v=(\w+)/, 1]

    expect(stamp).to(eq(Digest::SHA256.file(described_class.directory.join(described_class::KAI_CORE)).hexdigest[0, 8]))
  end

  it "gives the same url every time so the cache entry is reused" do
    with_base("https://fonts.example.test")

    expect(described_class.kai_core_url).to(eq(described_class.kai_core_url))
  end

  it "counts the sliced faces as installed only when a slice is present" do
    expect(described_class.kai_faces.first.basename.to_s).to(eq(described_class::KAI_CORE))
  end

  it "leaves the stamp off a file it cannot find" do
    with_base("https://fonts.example.test")

    expect(described_class.url_for("nothing-here.woff2")).to(eq("https://fonts.example.test/fonts/nothing-here.woff2"))
  end
end
