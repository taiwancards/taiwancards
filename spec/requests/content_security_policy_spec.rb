# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The content security policy", :no_auth do
  def policy
    get(login_path)
    response.headers["Content-Security-Policy"].to_s
  end

  it "lets the sign-in form hand the visitor over to Google" do
    expect(policy).to(match(/form-action [^;]*https:\/\/accounts\.google\.com/))
  end

  it "carries a usable nonce on the very first page a visitor sees" do
    expect(policy).to(match(/'nonce-[^']+'/))
  end

  it "keeps forms from posting anywhere else" do
    expect(policy).to(match(/form-action 'self'/))
  end
end
