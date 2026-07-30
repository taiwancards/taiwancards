# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityEvent do
  let(:user) { create(:user) }

  def track(controller: "dict", action: "index", path: "/dict")
    described_class.record(user:, controller:, action:, verb: "GET", path:)
  end

  it "records the first visit to a section" do
    expect { track }.to(change(described_class, :count).by(1))
  end

  it "collapses repeated visits inside the throttle window" do
    track

    expect { 20.times { track } }.not_to(change(described_class, :count))
  end

  it "records each section separately" do
    track(controller: "dict")
    track(controller: "characters")

    expect(described_class.pluck(:controller)).to(contain_exactly("dict", "characters"))
  end

  it "records each action separately" do
    track(action: "index")
    track(action: "show")

    expect(described_class.count).to(eq(2))
  end

  it "keeps users apart" do
    other = create(:user)
    track
    described_class.record(user: other, controller: "dict", action: "index", verb: "GET", path: "/dict")

    expect(described_class.pluck(:user_id)).to(contain_exactly(user.id, other.id))
  end

  it "ignores signed-out traffic" do
    expect {
      described_class.record(user: nil, controller: "dict", action: "index", verb: "GET", path: "/dict")
    }
      .not_to(change(described_class, :count))
  end

  it "ignores the controllers that would log themselves" do
    described_class::SKIPPED_CONTROLLERS.each { |name| track(controller: name) }

    expect(described_class.count).to(be_zero)
  end

  it "truncates an overlong path rather than failing" do
    track(path: "/dict/#{"x" * 400}")

    expect(described_class.last.path.length).to(eq(255))
  end

  it "never lets a tracking failure reach the request" do
    allow(described_class).to(receive(:create!).and_raise(ActiveRecord::StatementInvalid, "boom"))

    expect { track }.not_to(raise_error)
  end

  describe ".prune" do
    def aged(controller:, at: (described_class::RETENTION + 1.day).ago)
      described_class.create!(user:, controller:, action: "index", verb: "GET", path: "/#{controller}", created_at: at)
    end

    it "deletes events past the retention window and keeps the rest" do
      aged(controller: "old")
      aged(controller: "fresh", at: Time.current)

      expect { described_class.prune }.to(change(described_class, :count).from(2).to(1))
      expect(described_class.pluck(:controller)).to(eq(["fresh"]))
    end

    it "removes at most one batch per call so the delete cannot hold a long lock" do
      3.times { |index| aged(controller: "c#{index}") }

      expect(described_class.prune(batch: 2)).to(eq(2))
      expect(described_class.prune_all).to(eq(1))
      expect(described_class.count).to(be_zero)
    end
  end

  describe "the sweep on write" do
    it "clears expired events without a worker, once per interval" do
      stale = described_class.create!(
        user:,
        controller: "old",
        action: "index",
        verb: "GET",
        path: "/old",
        created_at: (described_class::RETENTION + 1.day).ago
      )

      track

      expect(described_class.exists?(stale.id)).to(be(false))
    end

    it "does not sweep again on the next write" do
      track
      allow(described_class).to(receive(:prune).and_call_original)

      track(controller: "characters")

      expect(described_class).not_to(have_received(:prune))
    end
  end
end
