# frozen_string_literal: true

require "rails_helper"

RSpec.describe "What a signed-out visitor costs the database", :no_auth do
  def queries_for(path)
    count = 0
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
      count += 1 unless payload[:name].to_s.in?(%w[SCHEMA TRANSACTION])
    end

    get(path)
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  it "never looks up a user that cannot exist" do
    seen = []
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
      seen << payload[:sql] if payload[:sql].to_s.match?(/FROM "users".*"users"\."id" IS NULL/m)
    end

    get("/en/practice/zhuyin")
    ActiveSupport::Notifications.unsubscribe(subscription)

    expect(seen).to(be_empty)
  end

  it "answers a page that needs no records without touching the database" do
    expect(queries_for("/en/practice/zhuyin")).to(eq(0))
  end
end
