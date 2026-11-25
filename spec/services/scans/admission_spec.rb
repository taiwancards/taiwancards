# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scans::Admission do
  let(:user) { create(:user) }
  let(:upload) { instance_double(Scans::Upload, size: 1000, width: 800, height: 600) }

  around { |example| with_scan_key(&example) }

  def admit(person = user, address: "203.0.113.7")
    described_class.new(user: person, address:, upload:).call
  end

  def fill(person, count, **attributes)
    count.times do
      Scan.create!(
        user: person,
        day: Scan.learner_day(person),
        bytes: 1,
        width: 1,
        height: 1,
        state: :done,
        **attributes
      )
    end
  end

  it "admits a scan and records the learner day, the size and the model" do
    result = admit

    expect(result).to(be_admitted)
    expect(result.scan).to(
      have_attributes(state: "queued", day: Scan.learner_day(user), width: 800, model: Scans::Settings::DEFAULT_MODEL)
    )
    expect(result.scan.client_digest).to(match(/\A\h{32}\z/))
  end

  it "stops at ten a day" do
    fill(user, Scan::DAILY)

    expect(admit.refusal).to(eq("quota"))
  end

  it "stops a learner whose scans keep failing on our side at twenty attempts" do
    fill(user, Scan::ATTEMPTS, state: :failed, failure: "timeout", counted: false)

    expect(admit.refusal).to(eq("quota"))
  end

  it "holds one network to a ceiling across accounts" do
    stub_const("ENV", ENV.to_h.merge("SCAN_CLIENT_DAILY" => "3", "SCAN_CONCURRENCY" => "10"))
    3.times { admit(create(:user)) }

    expect(admit.refusal).to(eq("client"))
    expect(admit(address: "198.51.100.9")).to(be_admitted)
  end

  it "treats one IPv6 /64 as one network" do
    first = described_class.client_digest("2001:db8:1:2:aaaa::1")

    expect(described_class.client_digest("2001:db8:1:2:bbbb::9")).to(eq(first))
    expect(described_class.client_digest("2001:db8:1:3::1")).not_to(eq(first))
    expect(described_class.client_digest("not an address")).to(be_nil)
  end

  it "switches itself off for the rest of the day when the global ceiling trips" do
    stub_const(
      "ENV",
      ENV.to_h.merge("SCAN_GLOBAL_DAILY" => "2", "SCAN_CLIENT_DAILY" => "50", "SCAN_CONCURRENCY" => "10")
    )
    2.times { admit(create(:user)) }

    expect(admit.refusal).to(eq("paused"))
    expect(ScanPause.current).to(have_attributes(reason: "ceiling"))
    expect(ScanPause.current.resumes_at).to(eq(Time.current.in_time_zone(Time.zone_default).end_of_day.floor(6)))
    admit
    expect(enqueued_jobs.select { |job| job["job_class"] == "ScanAlertJob" }.map { |job| job["arguments"].first })
      .to(eq(["ceiling"]))
  end

  it "refuses every upload while the key is rejected, without counting the attempt, until a check succeeds" do
    Scans::Credentials.rejected(Scans::Settings.key)

    3.times { expect(admit.refusal).to(eq("unavailable")) }
    expect(Scan.where(user:).count).to(eq(0))
    expect(Scan.remaining(user)).to(eq(Scan::DAILY))

    provider_answers(:ok)
    Scans::Credentials.check
    expect(admit).to(be_admitted)
  end

  it "refuses while too many scans are being read" do
    stub_const("ENV", ENV.to_h.merge("SCAN_CONCURRENCY" => "1"))
    fill(create(:user), 1, state: :running)

    expect(admit.refusal).to(eq("busy"))
  end

  it "refuses while paused and when no key is set" do
    ScanPause.trip!("credit")
    expect(admit.refusal).to(eq("paused"))

    ScanPause.delete_all
    ENV.delete("ANTHROPIC_API_KEY")
    expect(admit.refusal).to(eq("unavailable"))
  end

  it "reaps scans left behind by a restart before counting" do
    stub_const("ENV", ENV.to_h.merge("SCAN_CONCURRENCY" => "1"))
    travel_to(10.minutes.ago) { fill(create(:user), 1, state: :running) }

    expect(admit).to(be_admitted)
  end

  describe "under concurrency" do
    self.use_transactional_tests = false

    let(:racer) { create(:user) }

    after do
      Scan.where(user: racer).delete_all
      racer.delete
    end

    it "lets exactly one of several parallel uploads take the tenth slot" do
      fill(racer, Scan::DAILY - 1)
      gate = Concurrent::CountDownLatch.new(1)

      results = Array
        .new(4) { |index|
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              gate.wait
              described_class.new(user: racer, address: "203.0.113.#{index + 1}", upload:).call
            end
          end
        }
        .tap { gate.count_down }
        .map(&:value)

      expect(results.count(&:admitted?)).to(eq(1))
      expect(results.reject(&:admitted?).map(&:refusal).uniq).to(eq(["quota"]))
      expect(Scan.where(user: racer).count).to(eq(Scan::DAILY))
    end
  end
end
