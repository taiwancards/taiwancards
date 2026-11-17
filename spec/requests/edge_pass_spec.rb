# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Edge pass cookie", :no_auth do
  let(:secret) { "edge-secret" }

  before { edge_pass_is(secret) }

  def edge_pass_is(value)
    allow(ENV).to(receive(:[]).and_call_original)
    allow(ENV).to(receive(:[]).with("EDGE_PASS").and_return(value))
  end

  def edge_pass_header = Array(response.headers["Set-Cookie"]).flat_map { it.split("\n") }.grep(/\Aedge_pass=/)

  def user_queries
    count = 0
    counter = -> (*, payload) { count += 1 if payload[:sql].include?("FROM \"users\"") }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  def hit = post("/hit", params: {path: "/grammar"}.to_json, headers: {"CONTENT_TYPE" => "text/plain"})

  it "hands the secret to a learner who signs in" do
    sign_in

    expect(edge_pass_header.sole).to(include("edge_pass=#{secret}", "httponly", "samesite=lax"))
    expect(cookies[:edge_pass]).to(eq(secret))
  end

  it "hands it to a learner who was signed in before the secret existed" do
    edge_pass_is("")
    sign_in
    expect(cookies[:edge_pass]).to(be_blank)

    edge_pass_is(secret)
    get(desk_path)

    expect(cookies[:edge_pass]).to(eq(secret))
  end

  it "replaces a rotated secret on the next response" do
    sign_in
    edge_pass_is("rotated-secret")

    hit

    expect(response).to(have_http_status(:no_content))
    expect(cookies[:edge_pass]).to(eq("rotated-secret"))
  end

  it "leaves a learner who already carries the secret alone" do
    sign_in

    get(desk_path)

    expect(response).to(have_http_status(:ok))
    expect(edge_pass_header).to(be_empty)
  end

  it "costs a page view nothing extra once the cookie is in place" do
    sign_in
    with_pass = user_queries { hit }
    expect(edge_pass_header).to(be_empty)

    edge_pass_is("")
    without_pass = user_queries { hit }

    expect(with_pass).to(eq(without_pass))
  end

  it "never hands it to a guest on a publicly cached page" do
    get("/grammar")

    expect(response.headers["Cache-Control"]).to(include("public"))
    expect(response.headers["Set-Cookie"]).to(be_blank)
    expect(cookies[:edge_pass]).to(be_blank)
  end

  it "takes it away on sign-out" do
    sign_in
    expect(cookies[:edge_pass]).to(eq(secret))

    delete("/logout")

    expect(edge_pass_header.sole).to(start_with("edge_pass=;"))
    expect(cookies[:edge_pass]).to(be_blank)
  end

  it "writes nothing when the secret is not configured" do
    edge_pass_is("")

    sign_in

    expect(edge_pass_header).to(be_empty)
    expect(cookies[:edge_pass]).to(be_blank)
  end
end
