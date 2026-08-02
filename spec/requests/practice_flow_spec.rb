# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Theory to practice and back" do
  it "offers exactly one call to practice on a theory part" do
    get(practice_zhuyin_path(part: "initials"))

    expect(response).to(have_http_status(:ok))
    expect(response.body.scan(CGI.escapeHTML(I18n.t("practice.practice_now.cta"))).size).to(eq(1))
  end

  it "tells the trainer which part the reader came from" do
    get(practice_zhuyin_path(part: "initials"))

    expect(response.body).to(include(CGI.escapeHTML(zhuyin_training_path(group: "initials", from: "initials"))))
  end

  it "sends the reader on to the next part when a round is over" do
    get(zhuyin_training_path(group: "initials", from: "initials"))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(
      include(CGI.escapeHTML(I18n.t("practice.part_next", title: I18n.t("practice.parts.finals"))))
    )
    expect(response.body).to(include(CGI.escapeHTML(practice_zhuyin_path(part: "initials"))))
    expect(response.body).not_to(include(I18n.t("zhuyin_trainer.leave")))
  end

  it "keeps the plain trainer unchanged when nobody came from theory" do
    get(zhuyin_training_path)

    expect(response.body).to(include(I18n.t("zhuyin_trainer.leave")))
    expect(response.body).not_to(
      include(CGI.escapeHTML(I18n.t("practice.part_previous", title: I18n.t("practice.parts.initials"))))
    )
  end

  it "returns from the sounds drill to the part that sent the reader there" do
    get(practice_drill_path(from: "tricky"))

    expect(response.body).to(
      include(CGI.escapeHTML(I18n.t("practice.part_previous", title: I18n.t("practice.parts.tricky"))))
    )
    expect(response.body).not_to(include(CGI.escapeHTML(I18n.t("practice.back_to_chart"))))
  end

  it "returns from the tone drill to the tone theory" do
    get(tones_path)
    expect(response.body).to(include(CGI.escapeHTML(tones_drill_path(from: "tones"))))

    get(tones_drill_path(from: "tones"))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("tones.drill.back"))))
  end

  it "hides the roadmap steps while the reader is inside a theory detour" do
    @authenticated_user.update!(prefs: @authenticated_user.prefs.merge("intro_stage" => "done"))

    get(zhuyin_training_path)
    expect(response.body).to(include(I18n.t("onboarding.path.back")))

    get(zhuyin_training_path(group: "initials", from: "initials"))
    expect(response.body).not_to(include(I18n.t("onboarding.path.back")))
  end

  it "ignores a made-up origin" do
    get(practice_drill_path(from: "../../etc"))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("practice.back_to_chart"))))
  end
end
