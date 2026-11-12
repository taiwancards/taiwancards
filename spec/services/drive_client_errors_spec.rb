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

  let(:token_requests) { [] }
  let(:connections) { [] }

  def allow_refresh(scope: User::DRIVE_SCOPE, token: "drive-token")
    @token_body = {access_token: token, expires_in: 3599, scope:}.to_json
  end

  def answer_drive(&block)
    @drive = block
  end

  def refuse_with(body, code: "403")
    answer_drive { instance_double(Net::HTTPForbidden, code:, body:) }
  end

  before do
    allow_refresh
    answer_drive { instance_double(Net::HTTPOK, code: "200", body: "{}") }
    allow_any_instance_of(Net::HTTP).to(receive(:request)) do |http, req|
      connections << http
      if http.address == "oauth2.googleapis.com"
        token_requests << req
        instance_double(Net::HTTPOK, code: "200", body: @token_body)
      else
        @drive.call(req)
      end
    end
  end

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
    answer_drive do |req|
      sent = req["Authorization"]
      instance_double(Net::HTTPOK, code: "200", body: "{}")
    end

    client.backups

    expect(sent).to(eq("Bearer drive-token"))
  end

  it "refreshes once no matter how many calls one operation makes" do
    client.backups
    client.download("file-id")

    expect(token_requests.length).to(eq(1))
  end

  it "records the scopes the refresh token really carries" do
    allow_refresh(scope: "email #{User::DRIVE_SCOPE}")

    client.backups

    expect(user.reload.drive_linked?).to(be(true))
  end

  it "gives up quickly instead of holding the request thread for a minute" do
    client.backups

    expect(connections.map(&:open_timeout).uniq).to(eq([described_class::OPEN_TIMEOUT]))
    expect(connections.map(&:read_timeout).uniq).to(eq([described_class::READ_TIMEOUT]))
    expect(connections.map(&:max_retries).uniq).to(eq([0]))
  end

  it "reports a Drive timeout as a Drive error" do
    answer_drive { raise Net::ReadTimeout }
    allow(Rails.logger).to(receive(:error))

    expect { client.backups }.to(raise_error(described_class::Error, /could not be reached/))
  end

  it "reports an unreachable token endpoint as a Drive error" do
    allow_any_instance_of(Net::HTTP).to(receive(:request).and_raise(SocketError, "getaddrinfo"))
    allow(Rails.logger).to(receive(:error))

    expect { client.backups }.to(raise_error(described_class::Error))
  end

  it "reports a malformed answer as a Drive error" do
    answer_drive { instance_double(Net::HTTPOK, code: "200", body: "<html>oops</html>") }

    expect { client.backups }.to(raise_error(described_class::Error, /unexpected answer/))
  end

  it "reports a malformed token answer as a Drive error" do
    @token_body = "not json"

    expect { client.backups }.to(raise_error(described_class::Error, /unexpected answer/))
  end
end
