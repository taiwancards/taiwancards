# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedAssets do
  after { described_class.forget_stamps! }

  def with_base(url)
    allow(ENV).to(receive(:[]).and_call_original)
    allow(ENV).to(receive(:[]).with("ASSETS_BASE_URL").and_return(url))
    described_class.forget_stamps!
  end

  it "serves from the app itself when no shared origin is set" do
    with_base(nil)

    expect(described_class.url_for("json", "cangjie5.json")).to(eq("/json/cangjie5.json"))
  end

  it "sends every mount to the shared origin when one is set" do
    with_base("https://assets.example.test")

    expect(described_class.url_for("json", "cangjie5.json")).to(start_with("https://assets.example.test/json/"))
    expect(described_class.url_for("fonts", "tw-kai-full.woff2")).to(start_with("https://assets.example.test/fonts/"))
  end

  it "stamps each file with its own contents" do
    with_base("https://assets.example.test")

    one = described_class.url_for("json", "cangjie5.json")[/\?v=(\w+)/, 1]
    two = described_class.url_for("fonts", "tw-kai-full.woff2")[/\?v=(\w+)/, 1]

    expect(one).to(be_present)
    expect(one).not_to(eq(two))
  end

  it "counts a file as carried once a shared origin serves it, even with nothing on disk" do
    with_base("https://assets.example.test")

    expect(described_class.carried?("json", "not-on-this-machine.json")).to(be(true))
  end

  it "counts a missing file as absent when the app has to serve it itself" do
    with_base(nil)

    expect(described_class.carried?("json", "not-on-this-machine.json")).to(be(false))
  end

  it "mounts exactly what the static middleware serves" do
    expect(described_class::MOUNTS).to(contain_exactly("fonts", "json"))
  end
end
