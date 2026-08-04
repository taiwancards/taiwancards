# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin insights" do
  let(:admin) { create(:user, :admin) }

  describe "presence" do
    it "records when a person was last here and counts the visit" do
      user = sign_in(create(:user))

      get("/dict")

      user.reload
      expect(user.last_seen_at).to(be_present)
      expect(user.visits_count).to(eq(1))
    end

    it "does not write on every request" do
      user = sign_in(create(:user))
      get("/dict")
      seen = user.reload.last_seen_at

      get("/characters")

      expect(user.reload.last_seen_at).to(eq(seen))
      expect(user.visits_count).to(eq(1))
    end

    it "counts a new visit after a long gap" do
      user = sign_in(create(:user))
      get("/dict")
      user.reload.update_columns(last_seen_at: 2.hours.ago)

      get("/characters")

      expect(user.reload.visits_count).to(eq(2))
    end

    it "counts the visit in the database, not from a stale copy in memory" do
      user = sign_in(create(:user))
      get("/dict")
      User.where(id: user.id).update_all("visits_count = visits_count + 5")

      user.seen!(2.hours.from_now)

      expect(user.reload.visits_count).to(eq(7))
    end

    it "leaves the impersonated account untouched" do
      sign_in(admin)
      member = create(:user)
      post(admin_impersonate_path(member))

      get("/dict")

      expect(member.reload.last_seen_at).to(be_nil)
    end
  end

  describe "the gear in the header" do
    it "is shown to an admin" do
      sign_in(admin)

      get(desk_path)

      expect(response.body).to(include(admin_users_path))
    end

    it "is hidden from everybody else" do
      sign_in(create(:user))

      get(desk_path)

      expect(response.body).not_to(include(admin_users_path))
    end
  end

  describe "the user list" do
    it "shows registration, presence and study numbers" do
      sign_in(admin)
      member = create(:user, email: "member@example.com")
      member.update_columns(last_seen_at: 1.hour.ago, visits_count: 7)

      get(admin_users_path)

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("member@example.com"))
      expect(response.body).to(include(I18n.t("admin.visits", count: 7)))
    end

    it "leads with the person who was here last, and switches to registration on demand" do
      sign_in(admin)
      veteran = create(:user, email: "veteran@example.com")
      veteran.update_columns(created_at: 10.days.ago, last_seen_at: 1.minute.ago)
      newcomer = create(:user, email: "newcomer@example.com")
      newcomer.update_columns(created_at: 1.hour.ago, last_seen_at: 3.days.ago)

      get(admin_users_path)
      expect(response.body.index("veteran@example.com")).to(be < response.body.index("newcomer@example.com"))

      get(admin_users_path(sort: "joined"))
      expect(response.body.index("newcomer@example.com")).to(be < response.body.index("veteran@example.com"))
    end

    it "ignores an unknown sort" do
      sign_in(admin)
      create(:user, email: "member@example.com")

      get(admin_users_path(sort: "email; drop table users"))

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("member@example.com"))
    end
  end

  describe "a single user" do
    it "shows their profile and their own activity" do
      sign_in(admin)
      member = create(:user, email: "member@example.com")
      ActivityEvent.create!(user: member, controller: "dict", action: "index", verb: "GET", path: "/dict")

      get(admin_user_path(member))

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("member@example.com"))
      expect(response.body).to(include("/dict"))
    end

    it "is closed to non-admins" do
      sign_in(create(:user))

      get(admin_user_path(create(:user)))

      expect(response).to(redirect_to(root_path))
    end
  end

  describe "the activity feed" do
    it "filters by person and window" do
      sign_in(admin)
      member = create(:user, email: "member@example.com")
      other = create(:user, email: "other@example.com")
      ActivityEvent.create!(user: member, controller: "dict", action: "index", verb: "GET", path: "/dict")
      ActivityEvent.create!(user: other, controller: "study_sessions", action: "show", verb: "GET", path: "/study")

      get(admin_activity_path(user_id: member.id, days: 30))

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("member@example.com"))
      expect(response.body).not_to(include("other@example.com"))
    end

    it "survives junk input" do
      sign_in(admin)
      member = create(:user, email: "member@example.com")
      ActivityEvent.create!(user: member, controller: "dict", action: "index", verb: "GET", path: "/dict")

      get(admin_activity_path(days: "999; drop table", user_id: "abc"))

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("member@example.com"))
    end

    it "never counts the whole event log, and reads a fixed number of queries whatever it holds" do
      sign_in(admin)
      member = create(:user, email: "member@example.com")
      seed = -> (from, count) do
        ActivityEvent.insert_all(
          count.times.map do |n|
            {
              user_id: member.id,
              controller: "dict",
              action: "index",
              verb: "GET",
              path: "/dict/#{from + n}",
              created_at: n.minutes.ago
            }
          end
        )
      end

      seed.call(0, 20)
      small = count_queries { get(admin_activity_path) }
      seed.call(100, 200)
      large = count_queries { get(admin_activity_path) }

      expect(response).to(have_http_status(:ok))
      expect(large.count).to(be <= small.count)
      expect(large.to_s).not_to(match(/SELECT COUNT\(\*\) FROM "activity_events"\s*$/))
      expect(large.to_s.scan(/FROM "activity_events"/).length).to(be <= 4)
    end

    it "keeps the feed inside the chosen window" do
      sign_in(admin)
      member = create(:user, email: "member@example.com")
      ActivityEvent.create!(
        user: member,
        controller: "dict",
        action: "index",
        verb: "GET",
        path: "/dict/ancient",
        created_at: 20.days.ago
      )

      get(admin_activity_path(days: 1))
      expect(response.body).not_to(include("/dict/ancient"))

      get(admin_activity_path(days: 30))
      expect(response.body).to(include("/dict/ancient"))
    end

    it "paginates the feed" do
      sign_in(admin)
      member = create(:user, email: "member@example.com")
      rows = 61.times.map do |n|
        {
          user_id: member.id,
          controller: "dict",
          action: "index",
          verb: "GET",
          path: "/dict/#{n}",
          created_at: n.minutes.ago
        }
      end

      ActivityEvent.insert_all(rows)

      get(admin_activity_path)
      expect(response.body).to(include("/dict/0"))
      expect(response.body).not_to(include("/dict/60"))

      get(admin_activity_path(page: 2))
      expect(response.body).to(include("/dict/60"))
    end
  end
end
