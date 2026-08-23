# frozen_string_literal: true

require "rails_helper"

RSpec.describe Google::DriveClient do
  let(:user) do
    create(
      :user,
      google_refresh_token: "refresh",
      google_access_token: "login-token-without-drive",
      google_token_expires_at: 1.hour.from_now
    )
  end

  let(:client) { described_class.new(user) }

  def allow_refresh(scope: User::DRIVE_SCOPE, token: "drive-token")
    allow(Net::HTTP).to(
      receive(:post_form).and_return(
        instance_double(Net::HTTPOK, body: {access_token: token, expires_in: 3599, scope:}.to_json)
      )
    )
  end

  def refuse_with(body, code: "403")
    allow_any_instance_of(Net::HTTP).to(receive(:request).and_return(instance_double(Net::HTTPForbidden, code:, body:)))
  end

  before { allow_refresh }

  it "repeats the reason Google gave for refusing" do
    refuse_with(
      {error: {code: 403, message: "Google Drive API has not been used in project 12345 before or it is disabled."}}.to_json
    )

    expect { client.backups }.to(raise_error(described_class::Error, /has not been used in project 12345/))
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

  it "mints a Drive token instead of reusing the narrow one a plain sign-in left behind" do
    sent = nil
    allow_any_instance_of(Net::HTTP).to(receive(:request)) do |_http, req|
      sent = req["Authorization"]
      instance_double(Net::HTTPOK, code: "200", body: "{}")
    end

    client.backups

    expect(sent).to(eq("Bearer drive-token"))
  end

  it "refreshes once no matter how many calls one operation makes" do
    allow_any_instance_of(Net::HTTP).to(
      receive(:request).and_return(instance_double(Net::HTTPOK, code: "200", body: "{}"))
    )

    client.backups
    client.download("file-id")

    expect(Net::HTTP).to(have_received(:post_form).once)
  end

  it "records the scopes the refresh token really carries" do
    allow_refresh(scope: "email #{User::DRIVE_SCOPE}")
    allow_any_instance_of(Net::HTTP).to(
      receive(:request).and_return(instance_double(Net::HTTPOK, code: "200", body: "{}"))
    )

    client.backups

    expect(user.reload.drive_linked?).to(be(true))
  end
end
