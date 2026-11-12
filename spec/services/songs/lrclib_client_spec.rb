# frozen_string_literal: true

require "rails_helper"

RSpec.describe Songs::LrclibClient do
  before { stub_const("#{described_class}::HOST", "https://lrclib.test") }

  it "holds a Puma thread for at most one short attempt" do
    seen = nil
    allow_any_instance_of(Net::HTTP).to(receive(:request)) do |http, _req|
      seen = http
      instance_double(Net::HTTPOK, is_a?: true, body: "[]")
    end

    described_class.new.search("月亮代表我的心")

    expect(seen.max_retries).to(eq(0))
    expect(seen.read_timeout).to(eq(8))
    expect(seen.open_timeout).to(eq(described_class::OPEN_TIMEOUT))
  end

  it "answers nothing when the lyrics service times out" do
    allow_any_instance_of(Net::HTTP).to(receive(:request).and_raise(Net::ReadTimeout))
    allow(Rails.logger).to(receive(:warn))

    expect(described_class.new.search("月亮代表我的心")).to(eq([]))
  end
end
