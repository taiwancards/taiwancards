# frozen_string_literal: true

require "rails_helper"
require "nokolexbor"

RSpec.describe "Admin newsletters" do
  let!(:admin) { sign_in(create(:user, :admin, locale: "ru")) }

  def complete_newsletter
    Newsletter.create!(
      subject_en: "News",
      subject_ru: "Новости",
      body_en: "<div>Hi</div>",
      body_ru: "<div>Привет</div>"
    )
  end

  it "keeps everyone else out" do
    sign_in(create(:user))

    get(admin_newsletters_path)

    expect(response).to(redirect_to(root_path))
  end

  it "starts a draft and autosaves it, answering with the rendered letter" do
    post(admin_newsletters_path)
    newsletter = Newsletter.last
    expect(response).to(redirect_to(edit_admin_newsletter_path(newsletter)))

    patch(
      admin_newsletter_path(newsletter, lang: "ru"),
      params: {
        newsletter: {
          subject_ru: "Тема",
          body_ru: "<div>Текст</div>",
          buttons: {"0" => {label_ru: "Открыть", url: "/ru/desk"}}
        }
      },
      as: :json
    )

    expect(response.parsed_body["html"]).to(include("Текст", "Открыть"))
    expect(newsletter.reload.buttons).to(eq([{"label_ru" => "Открыть", "url" => "/ru/desk"}]))
  end

  it "shows the letter in the preview frame straight away" do
    newsletter = complete_newsletter

    get(edit_admin_newsletter_path(newsletter, lang: "ru"))

    frame = Nokolexbor::HTML(response.body).at_css("iframe[data-newsletter-editor-target=frame]")
    expect(frame["srcdoc"]).to(include("<html", "Привет", I18n.t("newsletters.mail.unsubscribe", locale: :ru)))
  end

  it "stores a screenshot and serves it to admins only" do
    newsletter = complete_newsletter
    file = Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png")

    post(admin_newsletter_images_path(newsletter), params: {file:})
    url = response.parsed_body["url"]
    get(url)

    expect(response.media_type).to(eq("image/png"))
    sign_in(create(:user))
    get(url)
    expect(response).to(redirect_to(root_path))
  end

  it "sends a sample to the admin alone, touching nobody else and starting no send" do
    newsletter = complete_newsletter
    create(:user, google_uid: "g-1", locale: "en")
    create(:user, google_uid: "g-2", locale: "ru")

    expect { post(sample_admin_newsletter_path(newsletter, lang: "en")) }.to(
      change { ActionMailer::Base.deliveries.size }.by(1)
    )
    expect(ActionMailer::Base.deliveries.last.to).to(eq([admin.email]))
    expect(NewsletterDelivery.pluck(:user_id, :locale, :sent_at)).to(eq([[admin.id, "en", nil]]))
    expect(NewsletterDispatchJob).not_to(have_been_enqueued)
    expect(newsletter.reload).not_to(be_sent)
  end

  it "queues one letter per recipient and locks the text" do
    newsletter = complete_newsletter
    create(:user, google_uid: "g-1", locale: "en")

    expect { post(deliver_admin_newsletter_path(newsletter)) }.to(
      have_enqueued_job(NewsletterDispatchJob).with(newsletter.id)
    )
    expect(newsletter.deliveries.pluck(:user_id)).to(match_array(Newsletter.recipients.ids))
    expect(newsletter.deliveries.pluck(:locale)).to(include("ru", "en"))

    patch(admin_newsletter_path(newsletter), params: {newsletter: {subject_ru: "Другая"}})
    expect(newsletter.reload.subject_ru).to(eq("Новости"))
  end

  it "refuses to send before both languages are written" do
    newsletter = Newsletter.create!(subject_ru: "Новости", body_ru: "<div>Привет</div>")

    post(deliver_admin_newsletter_path(newsletter))

    expect(newsletter.deliveries).to(be_empty)
    expect(flash[:alert]).to(eq(I18n.t("newsletters.admin.incomplete")))
  end
end
