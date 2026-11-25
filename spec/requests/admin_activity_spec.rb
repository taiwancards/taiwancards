# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin activity" do
  it "records what a signed-in person visits" do
    user = sign_in(create(:user))

    expect { get("/dict") }.to(change(ActivityEvent, :count).by(1))

    event = ActivityEvent.last
    expect(event.user).to(eq(user))
    expect(event.controller).to(eq("dict"))
    expect(event.path).to(eq("/dict"))
    expect(event.verb).to(eq("GET"))
  end

  it "does not record activity performed while impersonating" do
    admin = sign_in(create(:user, :admin))
    member = create(:user)
    post(admin_impersonate_path(member))

    expect { get("/dict") }.not_to(change(ActivityEvent, :count))
    expect(ActivityEvent.where(user: member)).to(be_empty)
    expect(admin).to(be_present)
  end

  it "shows the dashboard to an admin with per-person and per-section totals" do
    sign_in(create(:user, :admin))
    get("/dict")

    get(admin_activity_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(User.owner_google_email))
    expect(response.body).to(include(I18n.t("admin.by_section")))
  end

  it "shows what the learner looked at instead of encoded addresses, in a fixed number of queries" do
    sign_in(create(:user, :admin))
    member = create(:user)
    sentence = create(:lexeme, :sentence, text: "我們明天見。")
    seed = -> (paths) do
      ActivityEvent.insert_all(
        paths.each_with_index.map do |path, n|
          {user_id: member.id, controller: "x", action: "show", verb: "GET", path:, created_at: n.seconds.ago}
        end
      )
    end

    seed.call(["/characters/%E9%9B%B6", "/dict/%E5%85%A7"])
    plain = count_queries { get(admin_activity_path) }
    seed.call(
      [
        "/sentences/#{sentence.public_id}",
        "/grammar/zhe-na-na",
        *create_list(:lexeme, 5, :sentence).map { |row| "/sentences/#{row.public_id}" }
      ]
    )
    labeled = count_queries { get(admin_activity_path) }

    expect(response.body).to(
      include("/characters/零", "/dict/內", "我們明天見。", Huayu::GrammarLessons.find("zhe-na-na").pattern)
    )
    expect(response.body).not_to(include("<span>/characters/%E9%9B%B6</span>"))
    expect(response.body).to(include("target=\"_blank\"", "rel=\"noopener\""))
    expect(labeled.count).to(eq(plain.count + 1))
  end

  it "is closed to non-admins" do
    sign_in(create(:user))

    get(admin_activity_path)

    expect(response).to(redirect_to(root_path))
  end

  it "prunes old events" do
    user = create(:user)
    ActivityEvent.create!(
      user:,
      controller: "words",
      action: "index",
      verb: "GET",
      path: "/x",
      created_at: 200.days.ago
    )
    ActivityEvent.create!(user:, controller: "words", action: "index", verb: "GET", path: "/y", created_at: 1.day.ago)

    ActivityEvent.prune

    expect(ActivityEvent.pluck(:path)).to(include("/y"))
    expect(ActivityEvent.pluck(:path)).not_to(include("/x"))
  end
end
