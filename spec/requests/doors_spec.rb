# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Doors for a newcomer", :no_auth do
  def google!(uid: "door-fresh", email: "door-fresh@example.com", locale: nil, headers: {})
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid:,
      info: {email:, name: "Door"},
      credentials: {token: "t", refresh_token: "r", expires_at: 2.hours.from_now.to_i}
    )
    if locale
      post("/auth/google_oauth2?intent=sign_in&locale=#{locale}", headers:)
      follow_redirect!(headers:)
    else
      get("/auth/google_oauth2/callback", headers:)
    end

    User.find_by(google_uid: uid)
  end

  def expect_shared_page
    expect(response).to(have_http_status(:ok))
    expect(response.headers["Cache-Control"]).to(include("public", "s-maxage="))
    expect(response.headers["Set-Cookie"]).to(be_blank)
  end

  def handover(door, text, name: nil)
    post("/doors/#{door}", params: {handover: {text:, name:}})
  end

  let!(:hello) { create(:lexeme, kind: :word, text: "你好", meanings: {"en" => "hello"}) }
  let!(:school) { create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"}) }

  describe "the four doors" do
    it "greets a guest at home with all four, each one tap from its tool" do
      get("/desk")

      expect_shared_page
      page = Nokogiri::HTML(response.body)
      doors = page.css("[data-door]").to_h { |card| [card["data-door"], card] }
      expect(doors.keys).to(eq(%w[exam words text lookup]))
      expect(doors["exam"].at("a")["href"]).to(eq("/en/exams"))
      expect(doors["exam"].css("a").map { |link| link["href"] }).to(include("/en/tocfl"))
      expect(doors["words"].at("a")["href"]).to(eq("/en/doors/words"))
      expect(doors["text"].at("a")["href"]).to(eq("/en/doors/text"))
      expect(doors["lookup"].at("form")["action"]).to(eq("/en/lookup"))
      expect(doors["lookup"].at("form")["method"]).to(eq("get"))
    end

    it "puts the same doors first on the landing" do
      get("/")

      main = Nokogiri::HTML(response.body).at("main")
      expect(main.at("section")["id"]).to(eq("doors"))
      expect(main.css("[data-door]").map { |card| card["data-door"] }).to(eq(%w[exam words text lookup]))
    end

    it(
      "serves the paste pages to guests from the edge, with a worked example and no field that could leak into an address"
    ) do
      %w[words text].each do |door|
        get("/doors/#{door}")

        expect_shared_page
        page = Nokogiri::HTML(response.body)
        form = page.at("form[action='/en/doors/#{door}/continue']")
        expect(form["method"]).to(eq("get"))
        expect(form.css("input[name], textarea[name], select[name]")).to(be_empty)
        expect(page.at("[data-controller='door-stash']")["data-door-stash-limit-value"]).to(eq("30000"))
      end

      get("/doors/words")
      expect(response.body).to(include("你好", "hello"))

      get("/doors/text")
      expect(response.body).to(include("data-controller=\"analyzer layers reading\""))
    end

    it "sends a signed-in learner straight to the full tools" do
      sign_in(create(:user))

      get("/doors/words")
      expect(response).to(redirect_to(new_desk_path))

      get("/doors/text")
      expect(response).to(redirect_to(new_reader_text_path))
    end
  end

  describe "looking a word up" do
    it "opens the dictionary page of a headword without a session" do
      get("/lookup", params: {q: " 學校 "})

      expect(response).to(redirect_to(dict_entry_path(text: "學校")))
      expect(response.headers["Set-Cookie"]).to(be_blank)
    end

    it "turns simplified characters into the Taiwan headword" do
      get("/lookup", params: {q: "学校"})

      expect(response).to(redirect_to(dict_entry_path(text: "學校")))
    end

    it "keeps search by pinyin or meaning behind the sign-in, and runs it right after" do
      get("/lookup", params: {q: "xuexiao"})

      expect(response).to(redirect_to(login_path))
      follow_redirect!
      expect(response.body).to(include(I18n.t("doors.sign_in.lookup")))

      user = google!(locale: "en", headers: {"Accept-Language" => "en-US,en;q=0.9"})
      expect(response).to(redirect_to("/en/doors/lookup/continue?q=xuexiao"))
      expect(user.entry_door).to(eq("lookup"))
      expect(user.goal).to(be_nil)

      follow_redirect!
      expect(response).to(redirect_to(search_path(q: "xuexiao")))
      expect(user.reload.door_reached_at).to(be_present)
    end

    it "searches at once for a signed-in learner, and sends long or mixed input to the search too" do
      sign_in(create(:user))

      get("/lookup", params: {q: "school"})
      expect(response).to(redirect_to(search_path(q: "school")))

      get("/lookup", params: {q: "學校 school"})
      expect(response).to(redirect_to(search_path(q: "學校 school")))

      get("/lookup", params: {q: "我" * 13})
      expect(response).to(redirect_to(search_path(q: "我" * 13)))
    end

    it "shrugs off an empty or malformed query" do
      get("/lookup")
      expect(response).to(redirect_to(dict_path))

      get("/lookup", params: {q: {"$ne" => "x"}})
      expect(response).to(redirect_to(dict_path))
    end
  end

  describe "handing pasted words over through the sign-in" do
    it "asks for the sign-in in the middle and comes back to finish the deck" do
      get("/doors/words/continue")
      expect(response).to(redirect_to(login_path))
      follow_redirect!
      expect(response.body).to(include(I18n.t("doors.sign_in.words")))

      user = google!(locale: "ru")

      expect(response).to(redirect_to("/en/doors/words/continue"))
      expect(user.prefs).to(include("entry_door" => "words", "goal" => "classes", "language_chosen" => true))

      follow_redirect!
      follow_redirect! if response.redirect?
      page = Nokogiri::HTML(response.body)
      expect(page.at("[data-controller='door-handover']")["data-door-handover-fallback-value"]).to(eq("/ru/desks/new"))
      expect(page.at("form[action='/ru/doors/words'] textarea[name='handover[text]']")).to(be_present)
      expect(response.body).not_to(include("id=\"goal-picker\""))
    end

    it "builds the deck from the pasted words and lands on it" do
      user = sign_in(create(:user, prefs: {"entry_door" => "words", "goal" => "classes", "language_chosen" => true}))

      expect { handover("words", "你好、学校、你好\nhello", name: "Lesson 1") }
        .to(change(Collection.where(user:), :count).by(1))

      desk = Collection.where(user:).last
      expect(desk.name).to(eq("Lesson 1"))
      expect(desk.lexemes).to(contain_exactly(hello, school))
      expect(response).to(redirect_to(my_desk_path(desk)))
      expect(flash[:notice]).to(eq(I18n.t("doors.words.built", count: 2)))
      expect(user.reload.door_reached_at).to(be_present)
    end

    it "opens the pasted text broken down line by line" do
      user = sign_in(create(:user, prefs: {"entry_door" => "text", "language_chosen" => true}))

      expect { handover("text", "你好。\n我們學校很大。") }.to(change(ReadingText.where(user:), :count).by(1))

      text = ReadingText.where(user:).last
      expect(response).to(redirect_to(reader_text_path(text)))
      expect(text.title).to(eq(I18n.t("reader.untitled")))
      expect(user.reload.door_reached_at).to(be_present)
    end

    it "refuses oversized, empty, malformed or character-less input without building anything" do
      user = sign_in(create(:user))
      decks = Collection.where(user:)

      expect do
        handover("words", "你" * 30_001)
        expect(response).to(redirect_to(new_desk_path))
        expect(flash[:alert]).to(include("30,000"))

        handover("words", "   ")
        expect(flash[:alert]).to(eq(I18n.t("doors.refused.empty")))

        post("/doors/words", params: {handover: {text: ["你好"]}})
        expect(flash[:alert]).to(eq(I18n.t("doors.refused.empty")))

        post("/doors/text", params: {handover: "你好"})
        expect(response).to(redirect_to(new_reader_text_path))

        handover("text", "only latin letters here")
        expect(flash[:alert]).to(eq(I18n.t("doors.refused.no_hanzi")))

        handover("words", "龘龘")
        expect(flash[:alert]).to(eq(I18n.t("doors.refused.no_words")))
      end
        .not_to(change { [decks.count, ReadingText.count] })
    end

    it "builds nothing for a guest" do
      expect { handover("words", "你好") }.not_to(change(Collection, :count))
      expect(response).to(redirect_to(login_path))
    end

    it "knows only the two pasted doors" do
      sign_in(create(:user))

      post("/doors/exam", params: {handover: {text: "你好"}})

      expect(response).to(have_http_status(:not_found))
    end

    it "asks the language first when the page did not answer it, then carries on to the hand-over" do
      get("/doors/text/continue")
      user = google!(locale: "en", headers: {"Accept-Language" => "vi-VN,vi;q=0.9", "CF-IPCountry" => "VN"})

      expect(user.prefs).to(include("entry_door" => "text"))
      expect(user.language_chosen?).to(be(false))

      follow_redirect!
      follow_redirect! if response.redirect?
      expect(response.body).to(include("language-step-title"))
      expect(response.body).to(include(I18n.t("doors.language_then.text", locale: user.locale)))

      post("/locale/vi", headers: {"HTTP_REFERER" => "http://www.example.com#{request.fullpath}"})
      expect(response).to(redirect_to("http://www.example.com/vi/doors/text/continue"))
      follow_redirect!

      expect(response.body).to(include("data-controller=\"door-handover\""))
    end
  end

  describe "keeping a guest's exam result" do
    let(:paper) { Huayu::TocflPapers.find("a-set1-listening") }

    before do
      manifest = {"bundles" => {paper.slug => {"digest" => "abc", "count" => 50, "parts" => []}}}
      allow(Huayu::TocflBundles::MANIFEST).to(receive(:value).and_return(manifest))
      Huayu::TocflBundles.reset!
    end

    after { Huayu::TocflBundles.reset! }

    it "offers a guest the save link and records the device attempt on the account after sign-in" do
      get("/exams/#{paper.slug}")
      player = Nokogiri::HTML(response.body).at("[data-controller='exam-player']")
      save = player["data-exam-player-save-value"]
      expect(save).to(eq("/en/doors/exam/continue?paper=#{paper.slug}"))
      expect(JSON.parse(player["data-exam-player-strings-value"])).to(include("door_save_cta", "door_saved"))

      get(save)
      user = google!(locale: "en", headers: {"Accept-Language" => "en-GB"})

      expect(user.prefs).to(include("entry_door" => "exam", "goal" => "tocfl"))
      follow_redirect!
      expect(response).to(redirect_to(exam_path(paper)))
      follow_redirect!
      player = Nokogiri::HTML(response.body).at("[data-controller='exam-player']")
      expect(player["data-exam-player-record-value"]).to(eq("/en/exams/#{paper.slug}/result"))
      expect(player["data-exam-player-save-value"]).to(be_nil)

      answers = paper.numbers.to_h { |number| [number.to_s, paper.answer(number)] }
      post(player["data-exam-player-record-value"], params: {answers:}, as: :json)

      expect(response.parsed_body).to(include("score" => paper.count))
      expect(user.reload.door_reached_at).to(be_present)
    end

    it "sends an unknown or foreign paper back to the hall" do
      sign_in(create(:user))

      get("/doors/exam/continue", params: {paper: "https://evil.example.org"})
      expect(response).to(redirect_to(exams_path))

      get("/doors/exam/continue", params: {paper: "//evil.example.org"})
      expect(response).to(redirect_to(exams_path))
    end

    it "treats a sign-in from the exam hall itself as the exam door" do
      get("/login", headers: {"HTTP_REFERER" => "http://www.example.com/en/exams"})
      user = google!

      expect(user.goal).to(eq("tocfl"))
      expect(response).to(redirect_to("/en/exams"))
    end
  end

  describe "after the door" do
    it "offers the questionnaire on the home page instead of forcing it" do
      sign_in(create(:user, prefs: {"entry_door" => "text", "language_chosen" => true}))

      get("/desk")

      expect(response.body).not_to(include("id=\"goal-picker\""))
      expect(response.body).to(include("id=\"setup-offer\"", "/en/start", "/en/path"))
      expect(response.body).not_to(include(I18n.t("setup.title")))
      expect(response.body).to(include(I18n.t("doors.setup.no_goal")))
    end

    it "still puts the start dialog in front of a newcomer who came through no door" do
      get("/login")
      google!
      follow_redirect!

      expect(response.body).to(include("id=\"goal-picker\""))
      expect(response.body).not_to(include("id=\"setup-offer\""))
    end

    it "takes an existing account through a door without touching its settings" do
      owner = create(:user, google_uid: "door-owner", email: "owner@example.com", prefs: {"goal" => "guided"})

      get("/doors/words/continue")
      google!(uid: "door-owner", email: "owner@example.com")

      expect(response).to(redirect_to("/en/doors/words/continue"))
      expect(owner.reload.prefs).to(eq("goal" => "guided"))
      follow_redirect!
      expect(response.body).to(include("data-controller=\"door-handover\""))
    end
  end

  describe "where a sign-in may send someone back to" do
    it "only ever returns to its own continue pages" do
      get("/doors/words/continue", headers: {"HTTP_REFERER" => "https://evil.example.org/steal"})
      google!

      expect(response).to(redirect_to("/en/doors/words/continue"))
    end

    it "never logs the pasted text" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      logged = filter.filter("handover" => {"text" => "我的日記", "name" => "Diary"}, "door" => "text")

      expect(logged).to(eq("handover" => {"text" => "[FILTERED]", "name" => "[FILTERED]"}, "door" => "text"))
    end
  end
end
