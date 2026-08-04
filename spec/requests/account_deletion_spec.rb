# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Deleting an account" do
  let(:admin) { create(:user, :admin) }

  it "leaves nothing of the person behind in the database" do
    victim = create(:user)
    owned = ActiveRecord::Base.connection.tables.select do |table|
      ActiveRecord::Base.connection.columns(table).any? { |column| column.name == "user_id" }
    end

    sign_in(admin)
    delete(admin_user_path(victim))

    expect(User.find_by(id: victim.id)).to(be_nil)
    owned.each do |table|
      left = ActiveRecord::Base.connection.select_value("SELECT count(*) FROM #{table} WHERE user_id = #{victim.id}")
      expect(left).to(eq(0), "#{table} still holds rows for the deleted account")
    end
  end

  it "covers every table that carries a user_id, so a new one cannot slip through" do
    owned = ActiveRecord::Base.connection.tables.select do |table|
      ActiveRecord::Base.connection.columns(table).any? { |column| column.name == "user_id" }
    end

    cleared = User.reflect_on_all_associations.select { |a| a.options[:dependent] }.filter_map do |a|
      a.klass.table_name
    rescue StandardError
      nil
    end

    expect(owned - cleared).to(be_empty)
  end

  it "logs the browser out and clears what it was carrying, so the next sign-in starts clean" do
    victim = sign_in(create(:user))
    cookies[ZhuyinHelper::HANZI_FONT_COOKIE] = "kai"
    cookies[DetailLevelHelper::DETAIL_COOKIE] = "brief"
    victim.destroy!

    get("/en/desk")

    expect(response).to(redirect_to(login_path))
    expect(cookies[:user_id]).to(be_blank)
    expect(cookies[ZhuyinHelper::HANZI_FONT_COOKIE]).to(be_blank)
    expect(cookies[DetailLevelHelper::DETAIL_COOKIE]).to(be_blank)
  end

  it "lets the account holder delete themselves, exactly as an admin would" do
    victim = sign_in(create(:user))
    create(:lexeme, kind: :word, text: "資料").then do |lexeme|
      Collection.create!(kind: :manual, name: "Mine", user: victim).add_lexeme(lexeme)
    end

    delete("/en/profile/account")

    expect(response).to(redirect_to(root_path))
    expect(User.find_by(id: victim.id)).to(be_nil)
    expect(Collection.where(user_id: victim.id)).to(be_empty)
    expect(cookies[:user_id]).to(be_blank)
  end

  it "greets a brand new account as new, not as one coming back", :no_auth do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "fresh-uid",
      info: {email: "fresh@example.com", name: "Fresh"},
      credentials: {token: "t", refresh_token: "r", expires_at: 2.hours.from_now.to_i}
    )

    get("/auth/google_oauth2/callback")

    expect(flash[:notice]).to(eq(I18n.t("auth.signed_up")))
    expect(flash[:notice]).not_to(eq(I18n.t("auth.signed_in")))
  end

  it "never confuses a deleted account with a live one, because ids are not reused" do
    victim = create(:user)
    id = victim.id
    victim.destroy!

    expect(create(:user).id).to(be > id)
  end
end
