# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scans::Incidents do
  def alerts(kind) = enqueued_jobs.count { |job| job["job_class"] == "ScanAlertJob" && job["arguments"].first == kind }

  it "writes to the owner once when credit runs out, however many uploads fail" do
    3.times { described_class.pause("credit") }

    expect(ScanPause.active.where(reason: "credit").count).to(eq(1))
    expect(alerts("credit")).to(eq(1))
  end

  it "writes again for a new incident after the pause has ended" do
    described_class.pause("credit")
    travel(7.hours) { described_class.pause("credit") }

    expect(alerts("credit")).to(eq(2))
  end

  it "stays quiet about rate limits and brief outages" do
    described_class.pause("rate_limited")
    described_class.pause("unavailable")

    expect(enqueued_jobs.select { |job| job["job_class"] == "ScanAlertJob" }).to(be_empty)
  end

  it "never lets a failure to queue the letter reach the caller" do
    allow(ScanAlertJob).to(receive(:perform_later).and_raise(StandardError, "queue full"))

    expect(described_class.pause("credit")).to(have_attributes(reason: "credit"))
  end

  it "reopens everything except the daily ceiling" do
    %w[credit rate_limited unavailable ceiling].each { |reason| ScanPause.trip!(reason) }

    expect(described_class.reopen).to(eq(3))
    expect(ScanPause.active.pluck(:reason)).to(eq(["ceiling"]))
    expect(ScanPause.count).to(eq(4))
  end
end
