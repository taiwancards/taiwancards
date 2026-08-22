# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  let!(:person) { described_class.create!(email: "someone@example.com", password: "password123") }

  it "signs nobody in outside development" do
    expect(described_class.signed_in_by_default?).to(be(false))
    expect(described_class.default_owner).to(be_nil)
    expect(person.admin?).to(be(false))
  end

  context("when running locally") do
    before { allow(Rails.env).to(receive(:development?).and_return(true)) }

    it "hands the session the owner without asking Google" do
      expect(described_class.default_owner).to(eq(person))
      expect(person.admin?).to(be(true))
    end

    it "steps aside while the static site is being exported" do
      Site.while_exporting do
        expect(described_class.default_owner).to(be_nil)
        expect(person.admin?).to(be(false))
      end
    end

    it "steps aside when DEV_LOGIN is turned off" do
      allow(ENV).to(receive(:[]).and_call_original)
      allow(ENV).to(receive(:[]).with("DEV_LOGIN").and_return(described_class::DEV_LOGIN_OFF))

      expect(described_class.default_owner).to(be_nil)
      expect(person.admin?).to(be(false))
    end
  end
end
