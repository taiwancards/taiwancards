# frozen_string_literal: true

require "rails_helper"

RSpec.describe Decks::Sharing do
  let(:owner) { create(:user) }

  def deck(name, user: owner) = Collection.create!(kind: :manual, name:, user:)

  def publish(name, user: owner, at: Time.current)
    travel_to(at) { described_class.publish_deck(deck(name, user:), user:) }
  end

  before { stub_const("DeckShare::MAX_ACTIVE_PER_USER", 2) }

  it "revokes the oldest live share once a new one would pass the cap" do
    oldest = publish("First", at: 3.hours.ago)
    middle = publish("Second", at: 2.hours.ago)

    newest = publish("Third")

    expect(DeckShare.where(user: owner).live).to(contain_exactly(middle, newest))
    expect(oldest.reload).to(be_revoked)
  end

  it "leaves another person's shares alone" do
    stranger = publish("Theirs", user: create(:user), at: 4.hours.ago)
    publish("First", at: 3.hours.ago)
    publish("Second", at: 2.hours.ago)

    publish("Third")

    expect(stranger.reload).to(be_live)
  end

  it "does not count a share already revoked against the cap" do
    publish("First", at: 3.hours.ago).revoke!
    kept = publish("Second", at: 2.hours.ago)

    newest = publish("Third")

    expect(DeckShare.where(user: owner).live).to(contain_exactly(kept, newest))
  end
end
