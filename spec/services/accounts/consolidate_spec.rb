# frozen_string_literal: true

require "rails_helper"

RSpec.describe Accounts::Consolidate do
  def next_id
    ActiveRecord::Base.connection.select_value("SELECT last_value + 1 FROM users_id_seq")
  end

  it "leaves the owner alone and removes everybody else" do
    owner = create(:user, :admin)
    create(:user)
    create(:user)

    result = described_class.new.call

    expect(result.deleted).to(eq(2))
    expect(User.pluck(:google_email)).to(eq([User::ADMIN_GOOGLE_EMAIL]))
    expect(User.sole.email).to(eq(owner.email))
  end

  it "gives the owner the first id and starts the next account at two" do
    create(:user)
    create(:user)
    owner = create(:user, :admin)
    expect(owner.id).to(be > 1)

    result = described_class.new.call

    expect(result.renumbered).to(be(true))
    expect(User.sole.id).to(eq(1))
    expect(next_id).to(eq(2))
  end

  it "keeps the id and says so plainly when the owner already has records to lose" do
    create(:user)
    owner = create(:user, :admin)
    deck = Collection.create!(kind: :manual, name: "Mine", user: owner)

    result = described_class.new.call

    expect(result.renumbered).to(be(false))
    expect(result.attached).to(be > 0)
    expect(User.sole.id).to(eq(owner.id))
    expect(deck.reload.user).to(eq(User.sole))
  end

  it "takes the deleted accounts' records with them" do
    other = create(:user)
    Collection.create!(kind: :manual, name: "Theirs", user: other)
    create(:user, :admin)

    described_class.new.call

    expect(Collection.where(user_id: other.id)).to(be_empty)
    expect(Collection.count).to(eq(0))
  end

  it "is safe to run twice" do
    create(:user, :admin)
    create(:user)
    described_class.new.call

    result = described_class.new.call

    expect(result.deleted).to(eq(0))
    expect(result.renumbered).to(be(false))
    expect(User.sole.id).to(eq(1))
    expect(next_id).to(eq(2))
  end

  it "refuses to run when the owner has never signed in" do
    create(:user)

    expect { described_class.new.call }.to(raise_error(ActiveRecord::RecordNotFound))
    expect(User.count).to(eq(1))
  end

  it "leaves the owner able to sign in and be recognised as the admin" do
    create(:user, :admin)
    described_class.new.call

    expect(User.sole).to(be_admin)
  end
end
