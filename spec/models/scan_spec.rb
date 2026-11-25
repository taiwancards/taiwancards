# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scan do
  let(:user) { create(:user, time_zone: "America/Los_Angeles") }

  def scan(**attributes)
    described_class.create!(
      {user:, day: described_class.learner_day(user), bytes: 1000, width: 800, height: 600}.merge(attributes)
    )
  end

  it "counts the day in the learner's own zone" do
    travel_to(Time.utc(2026, 11, 24, 3, 0)) do
      expect(described_class.learner_day(user)).to(eq(Date.new(2026, 11, 23)))
    end
  end

  it "leaves ten scans a day and gives back the ones that failed on our side" do
    3.times { scan(state: :done) }
    scan(state: :running).fail!("timeout")
    scan(state: :running).fail!("refused")

    expect(described_class.remaining(user)).to(eq(6))
  end

  it "lets only one runner claim a queued scan" do
    record = scan

    expect(record.claim!).to(be(true))
    expect(described_class.find(record.id).claim!).to(be(false))
  end

  it "settles a scan only once" do
    record = scan(state: :running)

    expect(record.fail!("interrupted")).to(be(true))
    expect(record.finish!(text: "好", legibility: "clear", changed: [], usage: {})).to(be(false))
    expect(record.reload).to(be_failed)
  end

  it "fails scans left behind by a restart and gives their slots back" do
    left = travel_to(5.minutes.ago) { scan(state: :running) }
    fresh = scan(state: :running)

    described_class.reap_stale

    expect(left.reload).to(have_attributes(state: "failed", failure: "interrupted", counted: false))
    expect(fresh.reload).to(be_running)
  end

  it "forgets the text and the network fingerprint after a day but keeps the count" do
    old = travel_to(25.hours.ago) { scan(state: :done, text: "藥袋", changed_chars: ["药"], client_digest: "abc") }
    recent = scan(state: :done, text: "菜單", client_digest: "def")

    described_class.purge_expired

    expect(old.reload).to(have_attributes(text: nil, changed_chars: [], client_digest: nil, state: "done"))
    expect(recent.reload.text).to(eq("菜單"))
    expect(described_class.where(user:).counted.count).to(eq(2))
  end

  it "goes with the account" do
    scan

    expect { user.destroy! }.to(change(described_class, :count).by(-1))
  end
end
