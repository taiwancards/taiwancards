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

  context("when a sync is forced") do
    around do |example|
      previous = ENV["FORCE_SYNC"]
      ENV["FORCE_SYNC"] = "1"
      example.run
    ensure
      ENV["FORCE_SYNC"] = previous
    end

    it "is stale regardless of the fingerprint" do
      described_class.new("probe", [path]).remember!

      expect(described_class.new("probe", [path]).stale?).to(be(true))
    end
  end

  it "ignores a missing source, so the step runs once and then settles" do
    missing = Rails.root.join("tmp/does_not_exist.json")
    guard = described_class.new("absent", [missing])

    expect(guard.files).to(be_empty)
    expect(guard.stale?).to(be(true))
    guard.remember!

    expect(described_class.new("absent", [missing]).stale?).to(be(false))
  end
end
