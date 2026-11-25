# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScanWatchJob do
  it "deletes recognized text older than a day even when nobody opens a scan page, then watches the key" do
    user = create(:user)
    old = travel_to(25.hours.ago) {
      Scan.create!(user:, day: Date.current, bytes: 1, width: 1, height: 1, state: :done, text: "舊")
    }
    fresh = Scan.create!(user:, day: Date.current, bytes: 1, width: 1, height: 1, state: :done, text: "新")
    allow(Scans::Credentials).to(receive(:watch))

    described_class.perform_now

    expect([old.reload.text, fresh.reload.text]).to(eq([nil, "新"]))
    expect(Scans::Credentials).to(have_received(:watch))
  end

  it "never raises" do
    allow(Scans::Credentials).to(receive(:watch).and_raise(ActiveRecord::ConnectionTimeoutError))

    expect { described_class.perform_now }.not_to(raise_error)
  end
end
