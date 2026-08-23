# frozen_string_literal: true

require "rails_helper"

RSpec.describe Google::DriveClient do
  let(:user) {
    create(
      :user,
      google_refresh_token: "refresh",
      google_access_token: "token",
      google_token_expires_at: 1.hour.from_now
    )
  }
  let(:client) { described_class.new(user) }

  def refuse_with(body, code: "403")
    response = instance_double(Net::HTTPForbidden, code:, body:)
    allow_any_instance_of(Net::HTTP).to(receive(:request).and_return(response))
  end

  it "repeats the reason Google gave for refusing" do
    refuse_with(
      {error: {code: 403, message: "Google Drive API has not been used in project 12345 before or it is disabled."}}.to_json
    )

    expect { client.backups }.to(
      raise_error(described_class::Error, /has not been used in project 12345/)
    )
  end

  it "still names the status when the body is not JSON" do
    refuse_with("<html>Forbidden</html>")

    expect { client.backups }.to(raise_error(described_class::Error, /403.*Forbidden/m))
  end

  it "logs the whole body so the reason survives past the flash message" do
    refuse_with({error: {message: "Insufficient Permission"}}.to_json)
    allow(Rails.logger).to(receive(:error))

    expect { client.backups }.to(raise_error(described_class::Error))
    expect(Rails.logger).to(have_received(:error).with(/Insufficient Permission/))
  end
end
