# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Page views", :no_auth do
  def hit(path, referrer: "", site: false, headers: {})
    post(
      "/hit",
      params: {path:, referrer:, site:}.to_json,
      headers: {"CONTENT_TYPE" => "text/plain", "User-Agent" => "Mozilla/5.0 (iPhone) Mobile", **headers}
    )
  end

  it "counts a view per day, page, source, device and country without a session" do
    2.times { hit("/ru/grammar/ba?x=1", referrer: "https://www.google.com/", headers: {"CF-IPCountry" => "tw"}) }

    expect(response).to(have_http_status(:no_content))
    expect(response.headers["Set-Cookie"]).to(be_blank)
    expect(PageView.sole).to(
      have_attributes(
        path: "/grammar/ba",
        locale: "ru",
        source: "search:google",
        device: "mobile",
        country: "TW",
        views: 2
      )
    )
  end

  it "tells the static site, internal moves and direct visits apart" do
    hit("/en/", site: true, referrer: "")
    hit("/en/dict", referrer: "http://www.example.com/en/desk")

    expect(PageView.pluck(:path, :source)).to(contain_exactly(["site:/", "direct"], ["/dict", "internal"]))
  end

  it "ignores anything that is not a path of ours" do
    hit("https://evil.example.org/")
    hit("/wp-admin/setup.php")
    post("/hit", params: "not json", headers: {"CONTENT_TYPE" => "text/plain"})
    post("/hit", params: "[1]", headers: {"CONTENT_TYPE" => "text/plain"})

    expect(PageView.count).to(eq(0))
  end

  it "shows the counts to an admin" do
    hit("/en/dict")
    sign_in(create(:user, :admin))

    get("/admin/traffic")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("/dict", "dict"))
  end
end
