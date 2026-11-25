# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The scan key in the admin" do
  let!(:admin) { sign_in(create(:user, :admin)) }

  around { |example| with_scan_key(&example) }

  def key = ScanCredential.current.api_key

  def save_key(secret = good_scan_key, expires_on: nil)
    post("/en/admin/scan_key", params: {secret:, expires_on:})
    follow_redirect!
  end

  it "shows the key block with the hint, the source and a write-only field, and is never cached" do
    get("/en/admin/scans")

    expect(response.headers["Cache-Control"]).to(include("no-store"))
    expect(response.body).to(
      include(I18n.t("scan.admin.key.title"), "…real", I18n.t("scan.admin.key.sources.environment"))
    )
    expect(response.body).not_to(include("test-key-not-real"))
    field = Nokogiri::HTML(response.body).at_css("input[name=secret]")
    expect(field.attributes.transform_values(&:value)).to(include("type" => "password", "autocomplete" => "off"))
    expect(field["value"]).to(be_nil)
  end

  it "saves a key the provider accepts and shows only its last four characters" do
    provider_answers(:ok)

    save_key(" #{good_scan_key} ", expires_on: "2026-12-01")

    expect(response.body).to(include(I18n.t("scan.admin.key.saved.ok", hint: "Zz9_")))
    expect(response.body).not_to(include(good_scan_key, good_scan_key.first(20)))
    expect(key).to(have_attributes(source: "stored", hint: "Zz9_"))
    expect(ScanCredential.current.expires_on).to(eq(Date.new(2026, 12, 1)))
    expect(flash.to_h.values.join).not_to(include(good_scan_key))
  end

  it "stores nothing the provider rejects" do
    provider_answers(:rejected)

    save_key

    expect(response.body).to(include(I18n.t("scan.admin.key.saved.rejected")))
    expect(key.source).to(eq("environment"))
  end

  it "keeps the secret out of the log, including the SQL that stores it" do
    provider_answers(:ok)
    log = StringIO.new
    logger = ActiveSupport::Logger.new(log)
    logger.level = :debug
    allow(Rails).to(receive(:logger).and_return(logger))
    ActionController::Base.logger = logger
    ActiveRecord::Base.logger = logger

    post("/en/admin/scan_key", params: {secret: good_scan_key})

    expect(log.string).to(include("[FILTERED]", "scan_credentials"))
    expect(log.string).not_to(include(good_scan_key, good_scan_key.first(24), good_scan_key.last(24)))
  ensure
    ActionController::Base.logger = Rails.application.config.logger || ActiveSupport::Logger.new(nil)
    ActiveRecord::Base.logger = Rails.application.config.logger || ActiveSupport::Logger.new(nil)
  end

  it "filters the parameter by name" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    expect(filter.filter("secret" => good_scan_key)).to(eq("secret" => "[FILTERED]"))
  end

  it "checks now, shows the rejected state with a banner on every admin page, and reopens after a good check" do
    provider_answers(:rejected)
    post("/en/admin/scan_key/check")
    follow_redirect!

    expect(response.body).to(
      include(I18n.t("scan.admin.key.checked.rejected"), I18n.t("scan.admin.key.status.rejected"))
    )

    get("/en/admin/mail")
    expect(response.body).to(include(I18n.t("scan.admin.health.rejected"), I18n.t("scan.admin.health.marker")))

    provider_answers(:ok)
    post("/en/admin/scan_key/check")
    get("/en/admin/mail")
    expect(response.body).not_to(include(I18n.t("scan.admin.health.rejected")))
  end

  it "removes the stored key and falls back to the environment key" do
    provider_answers(:ok)
    save_key

    delete("/en/admin/scan_key")
    follow_redirect!

    expect(response.body).to(include(I18n.t("scan.admin.key.forgotten.ok")))
    expect(key.source).to(eq("environment"))
  end

  it "switches the model from the admin after checking access, and lists only priced models" do
    get("/en/admin/scans")
    options = Nokogiri::HTML(response.body).css("select[name=model] option").map { _1["value"] }
    expect(options).to(eq(["", *Scans::Pricing::PER_MILLION.keys]))

    provider_answers(:ok)
    post("/en/admin/scan_model", params: {model: "claude-opus-5-5"})
    follow_redirect!

    expect(response.body).to(include(I18n.t("scan.admin.model_choice.saved.ok", model: "claude-opus-5-5")))
    expect(Scans::Settings.model).to(eq("claude-opus-5-5"))
    expect(Nokogiri::HTML(response.body).at_css("select[name=model] option[selected]")["value"]).to(
      eq("claude-opus-5-5")
    )
  end

  it "reopens every pause but the daily ceiling" do
    ScanPause.trip!("credit")
    ScanPause.trip!("ceiling")

    post("/en/admin/scans/reopen")

    expect(ScanPause.active.pluck(:reason)).to(eq(["ceiling"]))
  end

  it "warns on every admin page when the stored key expires within two days" do
    provider_answers(:ok)
    save_key(expires_on: (Time.current.in_time_zone(Time.zone_default).to_date + 2).iso8601)

    get("/en/admin/users")

    expect(response.body).to(include(I18n.t("scan.admin.health.expiring")))
  end

  it "keeps everyone else out" do
    sign_in(create(:user))
    provider_answers(:ok)

    post("/en/admin/scan_key", params: {secret: good_scan_key})

    expect(response).to(redirect_to(%r{/en\z}))
    expect(key.source).to(eq("environment"))
    expect(Scans::KeyCheck).not_to(have_received(:call))
  end

  it "refuses to change the key while the admin is looking through a learner's eyes" do
    learner = create(:user)
    post("/admin/impersonate/#{learner.id}")
    provider_answers(:ok)

    post("/en/admin/scan_key", params: {secret: good_scan_key})

    expect(key.source).to(eq("environment"))
    expect(Scans::KeyCheck).not_to(have_received(:call))
  end

  it "limits how often the key can be changed" do
    provider_answers(:ok)
    allow(Admin::ScanKeysController.cache_store).to(receive(:increment).and_return(13))

    post("/en/admin/scan_key", params: {secret: good_scan_key})
    follow_redirect!

    expect(response.body).to(include(I18n.t("scan.admin.key.too_fast")))
    expect(Scans::KeyCheck).not_to(have_received(:call))
  end
end
