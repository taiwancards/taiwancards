# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Who the request came from", :no_auth do
  it "names the reader rather than the edge that carried them" do
    get("/en/grammar", headers: {"HTTP_X_FORWARDED_FOR" => "203.0.113.7, 172.71.82.11"})

    expect(request.remote_ip).to(eq("203.0.113.7"))
  end

  it "keeps every Cloudflare range out of the answer" do
    %w[104.22.66.210 172.70.143.169 162.158.171.29 198.41.227.143 104.23.197.232].each do |edge|
      get("/en/grammar", headers: {"HTTP_X_FORWARDED_FOR" => "203.0.113.7, #{edge}"})

      expect(request.remote_ip).to(eq("203.0.113.7"), "#{edge} was reported as the reader")
    end
  end

  it "falls back to the edge when nobody else is named" do
    get("/en/grammar", headers: {"HTTP_X_FORWARDED_FOR" => "172.71.82.11"})

    expect(request.remote_ip).to(eq("172.71.82.11"))
  end
end
