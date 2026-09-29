# frozen_string_literal: true

require "rails_helper"

RSpec.describe Newsletters::Tracking do
  let(:delivery) { instance_double(NewsletterDelivery, id: 42) }

  it "signs the delivery and the target together" do
    token = described_class.token(delivery, "http://www.example.com/ru/desk")

    expect(described_class.read(token)).to(eq([42, "http://www.example.com/ru/desk"]))
    expect(described_class.read("#{token}x")).to(be_nil)
  end

  it "only treats links to the app itself as ours" do
    expect(described_class.ours?(described_class.absolute("/ru/desk"))).to(be(true))
    expect(described_class.ours?("https://evil.test/ru/desk")).to(be(false))
    expect(described_class.ours?("mailto:hi@example.com")).to(be(false))
  end
end
