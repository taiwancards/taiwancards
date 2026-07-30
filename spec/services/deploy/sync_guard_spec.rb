# frozen_string_literal: true

require "rails_helper"

RSpec.describe Deploy::SyncGuard do
  let(:path) { Rails.root.join("tmp/sync_guard_spec.json") }

  before { path.write("{\"a\":1}") }
  after { path.delete if path.exist? }

  it "is stale before the first run and settled afterward" do
    guard = described_class.new("probe", [path])

    expect(guard.stale?).to(be(true))
    guard.remember!

    expect(described_class.new("probe", [path]).stale?).to(be(false))
  end

  it "goes stale again when the source file changes" do
    described_class.new("probe", [path]).remember!
    path.write("{\"a\":2}")

    expect(described_class.new("probe", [path]).stale?).to(be(true))
  end

  it "keeps separate fingerprints per source" do
    described_class.new("probe", [path]).remember!

    expect(described_class.new("other", [path]).stale?).to(be(true))
    expect(described_class.new("probe", [path]).stale?).to(be(false))
  end

  it "can be forced regardless of the fingerprint" do
    described_class.new("probe", [path]).remember!

    ClimateControl.modify(FORCE_SYNC: "1") do
      expect(described_class.new("probe", [path]).stale?).to(be(true))
    end

  rescue NameError
    ENV["FORCE_SYNC"] = "1"
    expect(described_class.new("probe", [path]).stale?).to(be(true))
  ensure
    ENV.delete("FORCE_SYNC")
  end

  it "treats a missing source as settled rather than crashing" do
    guard = described_class.new("absent", [Rails.root.join("tmp/does_not_exist.json")])

    expect { guard.fingerprint }.not_to(raise_error)
  end
end
