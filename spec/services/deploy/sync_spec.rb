# frozen_string_literal: true

require "rails_helper"

RSpec.describe Deploy::Sync do
  let(:io) { StringIO.new }

  before do
    allow(MaintenanceWindow).to(receive(:open!))
    allow(Deploy::DerivedCaches).to(receive_messages(refresh: nil, edge_configured?: false, purge_edge: nil))
    stub_const("Deploy::SyncSteps::STEPS", [])
  end

  it "runs every always-step, then drops and re-warms the derived caches" do
    stub_const("Deploy::SyncSteps::ALWAYS", {"probe" => -> { :ran }, "quiet" => -> { :skipped }})

    report = described_class.new(scope: nil, io:).call

    expect(report.ran).to(eq(%w[probe derived_caches]))
    expect(report.skipped).to(eq(["quiet", "edge_purge (unconfigured)"]))
    expect(Deploy::DerivedCaches).to(have_received(:refresh))
  end

  it "leaves the caches alone when only warming steps ran" do
    stub_const("Deploy::SyncSteps::ALWAYS", {"landing_counts" => -> { :ran }})

    report = described_class.new(scope: nil, io:).call

    expect(report.skipped).to(include("derived_caches"))
    expect(Deploy::DerivedCaches).not_to(have_received(:refresh))
  end

  it "skips account steps and the cache work under the content scope" do
    stub_const("Deploy::SyncSteps::ALWAYS", {"google_scopes" => -> { raise "must not run" }, "probe" => -> { :ran }})

    report = described_class.new(scope: "content", io:).call

    expect(report.ran).to(eq(%w[probe]))
    expect(report.skipped).to(
      eq(["google_scopes (account)", "derived_caches (content scope)", "edge_purge (content scope)"])
    )
    expect(Deploy::DerivedCaches).not_to(have_received(:refresh))
  end

  it "records a failing step and carries on" do
    stub_const("Deploy::SyncSteps::ALWAYS", {"broken" => -> { raise ArgumentError, "boom" }, "probe" => -> { :ran }})
    expect_any_instance_of(described_class).to(
      receive(:warn).with(/deploy:sync step broken failed: ArgumentError: boom/)
    )

    report = described_class.new(scope: nil, io:).call

    expect(report.failed).to(eq(["broken (ArgumentError)"]))
    expect(report.ran).to(include("probe"))
    expect(report.to_s).to(include("FAILED [broken (ArgumentError)]"))
  end

  it "purges the edge only after content really changed" do
    stub_const("Deploy::SyncSteps::ALWAYS", {"probe" => -> { :ran }})
    allow(Deploy::DerivedCaches).to(receive(:edge_configured?).and_return(true))

    report = described_class.new(scope: nil, io:).call

    expect(report.ran).to(include("edge_purge"))
    expect(Deploy::DerivedCaches).to(have_received(:purge_edge))
  end
end
