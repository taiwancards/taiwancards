# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scans::Credentials do
  around { |example| with_scan_key(&example) }

  def status = ScanCredential.current.status

  def key = ScanCredential.current.api_key

  def alerts(kind) = enqueued_jobs.count { |job| job["job_class"] == "ScanAlertJob" && job["arguments"].first == kind }

  describe "checking" do
    it "moves an unchecked key to ok and records the check" do
      provider_answers(:ok)

      expect(described_class.check).to(eq(:ok))
      expect(status).to(eq("ok"))
      expect(ScanCredential.current.last_check_at).to(be_within(5.seconds).of(Time.current))
    end

    it "moves a key the provider refuses to rejected and writes to the owner once" do
      provider_answers(:rejected)

      3.times { described_class.check }

      expect(status).to(eq("rejected"))
      expect(alerts("rejected")).to(eq(1))
    end

    it "leaves the state alone when the provider cannot be reached" do
      provider_answers(:unreachable)

      expect(described_class.check).to(eq(:unreachable))
      expect(status).to(eq("unchecked"))
    end

    it "stays rejected until a check succeeds" do
      provider_answers(:rejected)
      described_class.check

      travel(1.day) { expect(status).to(eq("rejected")) }

      provider_answers(:ok)
      described_class.check
      expect(status).to(eq("ok"))
    end
  end

  describe "what scans report" do
    it "turns a successful scan into ok and a refused one into rejected, one letter per incident" do
      described_class.succeeded(key)
      expect(status).to(eq("ok"))

      2.times { described_class.rejected(key) }
      expect(status).to(eq("rejected"))
      expect(alerts("rejected")).to(eq(1))

      described_class.succeeded(key)
      described_class.rejected(key)
      expect(alerts("rejected")).to(eq(2))
    end

    it "ignores a refusal of a key that is no longer in use" do
      old = key
      provider_answers(:ok)
      described_class.save(good_scan_key)

      expect(described_class.rejected(old)).to(be(false))
      expect(status).to(eq("ok"))
      expect(alerts("rejected")).to(eq(0))
    end
  end

  describe "saving a key" do
    it "checks it first, stores it, reopens scanning and returns only the hint" do
      ScanCredential.row!.update!(state: "rejected", checked_digest: key.digest)
      ScanPause.trip!("credit")
      ScanPause.trip!("ceiling")
      provider_answers(:ok)

      saved = described_class.save("  #{good_scan_key}\n")

      expect(saved).to(have_attributes(outcome: :ok, hint: "Zz9_"))
      expect(saved.inspect).not_to(include(good_scan_key))
      expect(key).to(have_attributes(source: "stored", hint: "Zz9_"))
      expect(status).to(eq("ok"))
      expect(ScanPause.active.pluck(:reason)).to(eq(["ceiling"]))
      expect(Scans::Settings.usable?).to(be(true))
    end

    it "stores nothing the provider refuses" do
      provider_answers(:rejected)

      expect(described_class.save(good_scan_key).outcome).to(eq(:rejected))
      expect(key.source).to(eq("environment"))
      expect(ScanCredential.where.not(secret: nil)).to(be_empty)
      expect(alerts("rejected")).to(eq(0))
    end

    it "refuses what does not look like a key without calling the provider" do
      expect(described_class.save("hello").outcome).to(eq(:malformed))
      expect(Scans::KeyCheck).not_to(have_received(:call))
    end

    it "refuses to store anything without encryption keys" do
      allow(ScanCredential).to(receive(:encryption_ready?).and_return(false))

      expect(described_class.save(good_scan_key).outcome).to(eq(:no_encryption))
      expect(Scans::KeyCheck).not_to(have_received(:call))
      expect(ScanCredential.count).to(eq(0))
    end
  end

  describe "choosing the model" do
    it "checks access to the model with the free call, then stores it ahead of SCAN_MODEL" do
      provider_answers(:ok)
      stub_const("ENV", ENV.to_h.merge("SCAN_MODEL" => "claude-opus-5-5"))

      expect(described_class.choose_model("claude-haiku-5-5")).to(eq(:ok))
      expect(Scans::KeyCheck).to(have_received(:call).with(key, model: "claude-haiku-5-5"))
      expect(Scans::Settings.model).to(eq("claude-haiku-5-5"))

      expect(described_class.choose_model("")).to(eq(:ok))
      expect(Scans::KeyCheck).to(have_received(:call).with(key, model: "claude-opus-5-5"))
      expect(Scans::Settings.model).to(eq("claude-opus-5-5"))
    end

    it "keeps the model when the key cannot use the new one" do
      provider_answers(:no_model)

      expect(described_class.choose_model("claude-fable-5-2")).to(eq(:no_model))
      expect(Scans::Settings.model).to(eq(Scans::Settings::DEFAULT_MODEL))
    end

    it "refuses a model that is not on the price list without calling the provider" do
      expect(described_class.choose_model("gpt-5")).to(eq(:unknown))
      expect(Scans::KeyCheck).not_to(have_received(:call))
    end

    it "falls back to Sonnet, the measured default, when nothing is chosen" do
      expect(Scans::Settings.model).to(eq("claude-sonnet-5-5"))
    end
  end

  it "goes back to the environment key, unchecked, then checks it, when the stored key is removed" do
    provider_answers(:ok)
    described_class.save(good_scan_key)
    provider_answers(:rejected)

    expect(described_class.forget).to(eq(:rejected))
    expect(key.source).to(eq("environment"))
    expect(status).to(eq("rejected"))
  end

  describe "the hourly watch" do
    it "checks a key whose last check is older than an hour, and only then" do
      provider_answers(:ok)
      described_class.check

      travel(30.minutes) { described_class.watch }
      expect(Scans::KeyCheck).to(have_received(:call).once)

      travel(61.minutes) { described_class.watch }
      expect(Scans::KeyCheck).to(have_received(:call).twice)
    end

    it "finds an expired key before a learner does" do
      provider_answers(:ok)
      described_class.check
      provider_answers(:rejected)

      travel(2.hours) { described_class.watch }

      expect(status).to(eq("rejected"))
      expect(alerts("rejected")).to(eq(1))
    end

    it "writes once that the stored key expires tomorrow" do
      provider_answers(:ok)
      today = Time.current.in_time_zone(Time.zone_default).to_date
      described_class.save(good_scan_key, expires_on: today + 3)

      described_class.watch
      expect(alerts("expiring")).to(eq(0))

      travel(2.days) { 3.times { described_class.watch } }
      expect(alerts("expiring")).to(eq(1))
    end
  end
end
