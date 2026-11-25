# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScanCredential do
  def stored(secret = good_scan_key, **attributes)
    described_class.row!.tap { |row| row.update!(secret:, hint: secret.last(4), set_at: Time.current, **attributes) }
  end

  it "has no key when neither the table nor the environment holds one" do
    expect(described_class.current).to(have_attributes(api_key: nil, status: "missing", usable?: false))
  end

  it "uses the environment key, unchecked until a check names it" do
    with_scan_key do
      credential = described_class.current

      expect(credential.api_key).to(have_attributes(source: "environment"))
      expect(credential).to(have_attributes(status: "unchecked", usable?: true))
    end
  end

  it "prefers a stored key and falls back to the environment once it is removed" do
    with_scan_key do
      stored

      expect(described_class.current.api_key).to(have_attributes(source: "stored", hint: "Zz9_"))

      described_class.row!.update!(secret: nil)
      expect(described_class.current.api_key).to(have_attributes(source: "environment"))
    end
  end

  it "keeps a recorded state only for the key it was recorded for" do
    with_scan_key do
      key = described_class.current.api_key
      described_class.row!.update!(state: "rejected", checked_digest: key.digest)
      expect(described_class.current).to(have_attributes(status: "rejected", usable?: false))

      stored
      expect(described_class.current.status).to(eq("unchecked"))
    end
  end

  it "encrypts the secret and never shows it" do
    row = stored

    raw = described_class.connection.select_value("SELECT secret FROM scan_credentials")
    expect(raw).not_to(include(good_scan_key))
    expect(row.inspect).not_to(include(good_scan_key))
    expect(row.stored_key.inspect).to(eq("#<Scans::ApiKey stored …Zz9_>"))
    expect(row.stored_key.to_json).not_to(include(good_scan_key))
    expect { Marshal.dump(row.stored_key) }.to(raise_error(TypeError))
  end

  it "holds a single row" do
    described_class.row!

    expect { described_class.create!(id: 2) }.to(raise_error(ActiveRecord::StatementInvalid))
  end

  it "treats a secret it cannot decrypt as absent rather than failing" do
    stored
    described_class.connection.execute("UPDATE scan_credentials SET secret = '{\"p\":\"bm9wZQ==\",\"h\":{}}'")

    with_scan_key do
      credential = described_class.current

      expect(credential.unreadable?).to(be(true))
      expect(credential.api_key.source).to(eq("environment"))
    end
  end

  it "counts the days left to the expiry date" do
    row = stored(expires_on: Date.new(2026, 12, 1))

    expect(row.days_left(Date.new(2026, 11, 29))).to(eq(2))
    expect(row.days_left(Date.new(2026, 12, 3))).to(eq(-2))
  end
end
