# frozen_string_literal: true

require "rails_helper"

RSpec.describe Render::Api do
  it "says which setting is missing rather than failing at the socket" do
    expect { described_class.new(key: nil, service: "srv-x").deploy! }
      .to(raise_error(described_class::Misconfigured, /RENDER_API_KEY/))

    expect { described_class.new(key: "k", service: nil).deploy! }
      .to(raise_error(described_class::Misconfigured, /RENDER_SERVER/))
  end

  it "asks Render to keep the build cache, so a data-only release stays fast" do
    api = described_class.new(key: "k", service: "srv-x")
    captured = nil
    allow(api).to(receive(:send_request)) do |_uri, request|
      captured = JSON.parse(request.body)
      double = instance_double(Net::HTTPOK, code: "201", body: "{\"id\":\"dep-1\",\"status\":\"created\"}")
      allow(double).to(receive(:is_a?).with(Net::HTTPSuccess).and_return(true))
      double
    end

    expect(api.deploy!.fetch("id")).to(eq("dep-1"))
    expect(captured).to(eq({"clearCache" => "do_not_clear"}))
  end

  it "reports what Render said when it refuses" do
    api = described_class.new(key: "k", service: "srv-x")
    refusal = instance_double(Net::HTTPUnauthorized, code: "401", body: "unauthorized")
    allow(refusal).to(receive(:is_a?).with(Net::HTTPSuccess).and_return(false))
    allow(api).to(receive(:send_request).and_return(refusal))

    expect { api.deploy! }.to(raise_error(described_class::Failed, /401.*unauthorized/))
  end
end
