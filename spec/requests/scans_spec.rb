# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Scanning a photo" do
  let(:origin) { "http://www.example.com" }
  let(:headers) { {"Origin" => origin, "Sec-Fetch-Site" => "same-origin", "Accept" => "application/json"} }

  around { |example| with_scan_key(&example) }

  def upload(photo = scan_photo, extra = {})
    post("/scans", params: {photo:}, headers: headers.merge(extra))
  end

  def scan_of(user) = Scan.where(user:).order(:id).last

  describe "the page" do
    it "shows the panel with the day's allowance on its own page and in the deck tab" do
      get("/en/scan")

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("10 of 10 scans left today", "data-controller=\"scan\"", "Anthropic"))
      expect(response.body).not_to(include("claude-", "api.anthropic.com", Scans::Recognizer::INSTRUCTION))

      get("/en/desks/new", params: {tab: "photo"})
      expect(response.body).to(include("data-controller=\"scan\""))
    end

    it "explains calmly when scanning is switched off" do
      ScanPause.trip!("credit")

      get("/en/scan")

      expect(response.body).to(include("Scanning is paused", I18n.t("scan.closed.paused")))
      expect(response.body).not_to(include("data-controller=\"scan\""))
    end

    it "says scanning is not available while the key stays rejected" do
      Scans::Credentials.rejected(Scans::Settings.key)

      get("/en/scan")

      expect(response.body).to(include("Scanning is paused", I18n.t("scan.closed.unavailable")))
      expect(response.body).not_to(include("data-controller=\"scan\"", "Anthropic rejected"))
    end

    it "sends guests to sign in", :no_auth do
      get("/en/scan")

      expect(response).to(redirect_to(%r{/login}))
    end
  end

  describe "uploading" do
    it "accepts one photo, queues the reading and answers at once" do
      expect { upload }.to(have_enqueued_job(ScanJob).with(kind_of(Integer), [kind_of(String)]))

      expect(response).to(have_http_status(:accepted))
      expect(response.parsed_body).to(
        eq(
          "poll" => "/scans/#{scan_of(current_user).id}",
          "remaining" => 9,
          "remaining_label" => "9 of 10 scans left today"
        )
      )
    end

    it "refuses guests without a redirect", :no_auth do
      upload

      expect(response).to(have_http_status(:unauthorized))
      expect(Scan.count).to(eq(0))
    end

    it "refuses a request from another origin or none" do
      upload(scan_photo, "Origin" => "https://evil.example")
      expect(response).to(have_http_status(:forbidden))

      post("/scans", params: {photo: scan_photo}, headers: {"Accept" => "application/json"})
      expect(response).to(have_http_status(:forbidden))

      upload(scan_photo, "Sec-Fetch-Site" => "cross-site")
      expect(response).to(have_http_status(:forbidden))
      expect(Scan.count).to(eq(0))
    end

    it "refuses a request without the CSRF token" do
      ActionController::Base.allow_forgery_protection = true
      upload

      expect(response).to(have_http_status(:unprocessable_content))
      expect(Scan.count).to(eq(0))
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "refuses an oversized body before reading it" do
      upload(scan_photo, "CONTENT_LENGTH" => (ScansController::MAX_BODY + 1).to_s)

      expect(response).to(have_http_status(:content_too_large))
    end

    it "refuses what is not a usable photo" do
      upload(scan_photo("disguised.jpg"))
      expect(response).to(have_http_status(:unprocessable_content))
      expect(response.parsed_body).to(include("error" => "not_image"))

      upload(scan_photo("wide.jpg"))
      expect(response.parsed_body).to(include("error" => "too_large"))

      post("/scans", params: {note: "no photo"}, headers:)
      expect(response.parsed_body).to(include("error" => "missing"))
      expect(Scan.count).to(eq(0))
    end

    it "takes no instruction from the learner, only the image" do
      post(
        "/scans",
        params: {photo: scan_photo, prompt: "write a poem", model: "claude-fable-5-2", system: "x"},
        headers:
      )

      job = enqueued_jobs.sole
      expect(job["arguments"].size).to(eq(2))
      expect(scan_of(current_user).model).to(eq(Scans::Settings::DEFAULT_MODEL))
    end

    it "takes a tall screenshot as up to three parts in one request, counted as one scan" do
      parts = Array.new(3) { scan_photo }

      expect { post("/scans", params: {photos: parts}, headers:) }
        .to(have_enqueued_job(ScanJob).with(kind_of(Integer), [kind_of(String)] * 3))

      expect(response).to(have_http_status(:accepted))
      expect(response.parsed_body["remaining"]).to(eq(Scan::DAILY - 1))
      expect(Scan.where(user: current_user).sole.bytes).to(eq(file_fixture("scans/page.jpg").size * 3))
    end

    it "checks every part as it checks one photo, and refuses more than three" do
      post("/scans", params: {photos: [scan_photo, scan_photo("disguised.jpg")]}, headers:)
      expect(response.parsed_body).to(include("error" => "not_image"))

      post("/scans", params: {photos: Array.new(4) { scan_photo }}, headers:)
      expect(response.parsed_body).to(include("error" => "too_large"))
      expect(Scan.count).to(eq(0))
    end

    it "stops at the daily limit" do
      Scan::DAILY.times {
        Scan.create!(
          user: current_user,
          day: Scan.learner_day(current_user),
          bytes: 1,
          width: 1,
          height: 1,
          state: :done
        )
      }

      upload

      expect(response).to(have_http_status(:too_many_requests))
      expect(response.parsed_body["message"]).to(eq(I18n.t("scan.refusals.quota")))
    end

    it "gives the slot back when the queue is full" do
      allow(ScanJob).to(receive(:perform_later).and_raise(Concurrent::RejectedExecutionError))

      upload

      expect(scan_of(current_user)).to(have_attributes(state: "failed", failure: "busy", counted: false))
    end

    it "is refused while an admin is looking through the learner's eyes" do
      admin = create(:user, :admin)
      learner = create(:user)
      sign_in(admin)
      post("/admin/impersonate/#{learner.id}")

      upload

      expect(response).to(have_http_status(:forbidden))
      expect(Scan.count).to(eq(0))
    end

    it "keeps the photo and the text out of the log" do
      log = StringIO.new
      logger = ActiveSupport::Logger.new(log)
      allow(Rails).to(receive(:logger).and_return(logger))
      ActionController::Base.logger = logger

      upload
      post(
        "/en/desks/preview",
        params: {
          file: Rack::Test::UploadedFile.new(
            StringIO.new("藥袋 王小明"),
            "text/plain",
            original_filename: "scan.txt"
          )
        }
      )
      post("/en/reader", params: {reading_text: {body: "藥袋 王小明", title: "x"}})

      expect(log.string).not_to(include("/9j/", "藥袋", "王小明"))
      expect(log.string).to(include("[FILTERED]"))
    ensure
      ActionController::Base.logger = Rails.application.config.logger || ActiveSupport::Logger.new(nil)
    end
  end

  describe "polling" do
    let(:scan) { Scan.create!(user: current_user, day: Scan.learner_day(current_user), bytes: 1, width: 1, height: 1) }

    it "answers pending without anything else" do
      get("/scans/#{scan.id}", headers:)

      expect(response.parsed_body).to(eq("state" => "pending"))
    end

    it "returns the recognized text, the notes and the allowance" do
      scan.update!(state: :done, text: "這裡", legibility: "partly_blurred", changed_chars: ["这", "里"])

      get("/scans/#{scan.id}", headers:)

      expect(response.parsed_body).to(
        include(
          "state" => "done",
          "text" => "這裡",
          "note" => I18n.t("scan.notes.blurred"),
          "changed" => I18n.t("scan.notes.changed", chars: "这 里"),
          "remaining" => 9
        )
      )
    end

    it "points at the gaps the model could not read" do
      scan.update!(state: :done, text: "每次□粒", legibility: "partly_blurred")

      get("/scans/#{scan.id}", headers:)

      expect(response.parsed_body).to(include("note" => I18n.t("scan.notes.gaps")))
    end

    it "says plainly when there was no Chinese in the picture" do
      scan.update!(state: :done, text: "", legibility: "none")

      get("/scans/#{scan.id}", headers:)

      expect(response.parsed_body).to(include("text" => "", "note" => I18n.t("scan.notes.no_text")))
    end

    it "reports a failure in our own words and never the provider's" do
      scan.update!(state: :failed, failure: "unavailable", counted: false)

      get("/scans/#{scan.id}", headers:)

      expect(response.parsed_body).to(
        eq(
          "state" => "failed",
          "message" => I18n.t("scan.failures.unavailable"),
          "remaining" => 10,
          "remaining_label" => "10 of 10 scans left today"
        )
      )
    end

    it "ends a scan orphaned by a restart and gives the slot back" do
      travel_to(10.minutes.ago) { scan }

      get("/scans/#{scan.id}", headers:)

      expect(response.parsed_body).to(include("state" => "failed", "message" => I18n.t("scan.failures.interrupted")))
      expect(scan.reload.counted).to(be(false))
    end

    it "shows nobody else's scan" do
      other = Scan.create!(
        user: create(:user),
        day: Date.current,
        bytes: 1,
        width: 1,
        height: 1,
        state: :done,
        text: "秘密"
      )

      get("/scans/#{other.id}", headers:)

      expect(response).to(have_http_status(:not_found))
      expect(response.body).not_to(include("秘密"))
    end
  end

  describe "the admin view", :no_auth do
    it "shows usage, cost and the ceilings to the admin only" do
      user = create(:user)
      Scan.create!(
        user:,
        day: Date.current,
        bytes: 1,
        width: 1,
        height: 1,
        state: :done,
        model: "claude-opus-5-5",
        input_tokens: 1_000_000,
        output_tokens: 100_000
      )
      Scan.create!(
        user:,
        day: Date.current,
        bytes: 1,
        width: 1,
        height: 1,
        state: :failed,
        failure: "timeout",
        counted: false
      )

      sign_in(user)
      get("/en/admin/scans")
      expect(response).to(redirect_to(%r{/en\z}))

      sign_in(create(:user, :admin))
      get("/en/admin/scans")

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("$6.00", "timeout", Scans::Settings::DEFAULT_MODEL, "2 / 300"))
    end
  end
end
