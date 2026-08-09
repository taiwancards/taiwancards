# frozen_string_literal: true

require "rails_helper"

RSpec.describe Accounts::Owner do
  it "creates the single owner when nothing is there yet" do
    result = described_class.new.call

    owner = User.find(result.id)
    expect(result.status).to(eq(:created))
    expect(owner.email).to(eq(User.owner_email))
    expect(owner.google_email).to(eq(User.owner_google_email))
    expect(owner).to(be_admin)
    expect(owner.restricted_content).to(be(true))
  end

  it "keeps the same row on a second run instead of making another one" do
    first = described_class.new.call
    second = described_class.new.call

    expect(second.id).to(eq(first.id))
    expect(second.status).to(eq(:kept))
    expect(second).not_to(be_changed)
    expect(User.count).to(eq(1))
  end

  it "repairs an account that holds only one half of the pair" do
    stray = create(:user, email: User.owner_email, google_email: nil)

    result = described_class.new.call

    expect(result.id).to(eq(stray.id))
    expect(stray.reload.google_email).to(eq(User.owner_google_email))
    expect(stray).to(be_admin)
  end

  it "releases a second account that grabbed the owner's google identity" do
    keeper = create(:user, email: User.owner_email, google_email: User.owner_google_email, google_uid: "keep")
    impostor = create(:user, email: "other@example.com", google_email: User.owner_google_email, google_uid: "steal")

    result = described_class.new.call

    expect(result.id).to(eq(keeper.id))
    expect(result.unlinked).to(eq(1))
    expect(impostor.reload.google_email).to(be_nil)
    expect(impostor.google_uid).to(be_nil)
    expect(impostor).not_to(be_admin)
    expect(keeper.reload).to(be_admin)
  end

  it "takes admin away from everybody else" do
    described_class.new.call
    other = create(:user)
    other.update_column(:admin, true)

    result = described_class.new.call

    expect(result.demoted).to(eq(1))
    expect(other.reload.admin).to(be(false))
  end

  it "adopts an account that signed in with Google before the owner row existed" do
    early = create(
      :user,
      email: "signed.in.first@example.com",
      google_email: User.owner_google_email,
      google_uid: "first"
    )

    result = described_class.new.call

    expect(result.id).to(eq(early.id))
    expect(early.reload.email).to(eq(User.owner_email))
    expect(early).to(be_admin)
    expect(User.count).to(eq(1))
  end

  describe "the admin rule" do
    it "needs both halves together" do
      expect(build(:user, email: User.owner_email, google_email: User.owner_google_email)).to(be_admin)
      expect(build(:user, email: "someone@example.com", google_email: User.owner_google_email)).not_to(be_admin)
      expect(build(:user, email: User.owner_email, google_email: "someone@example.com")).not_to(be_admin)
      expect(build(:user, email: User.owner_email, google_email: nil)).not_to(be_admin)
    end

    it "keeps the admin column in step with the rule" do
      user = create(:user, :admin)
      expect(user.reload.admin).to(be(true))

      user.update!(email: "someone@example.com")
      expect(user.reload.admin).to(be(false))
    end
  end
end
