# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsletterMailer do
  let(:user) { create(:user, google_uid: "g-1", locale: "ru") }
  let(:newsletter) do
    Newsletter.create!(
      subject_en: "News",
      subject_ru: "Новости",
      preheader_ru: "Коротко",
      body_en: "<div>Hi</div>",
      body_ru: "<div>Привет, <a href=\"/ru/desk\">загляните</a> и <a href=\"https://example.org\">сюда</a></div>",
      buttons: [{"label_ru" => "Открыть", "label_en" => "Open", "url" => "/ru/pronunciation"}]
    )
  end

  def delivery = NewsletterDelivery.create!(newsletter:, user:, locale: "ru")

  it "writes in the reader's language, from a person, with a one-click unsubscribe" do
    mail = described_class.issue(delivery)

    expect(mail.subject).to(eq("Новости"))
    expect(mail[:from].value).to(include("丹丹 из TaiwanCards", MailSettings.from_address))
    expect(mail["List-Unsubscribe"].value).to(match(%r{\A<http://www\.example\.com/unsubscribe/.+>\z}))
    expect(mail["List-Unsubscribe-Post"].value).to(eq("List-Unsubscribe=One-Click"))
  end

  it "tracks links into the app, leaves other links alone and carries a text part" do
    mail = described_class.issue(delivery)
    html = mail.html_part.body.decoded

    expect(html.scan(%r{http://www\.example\.com/n/}).size).to(eq(2))
    expect(html).to(include("https://example.org", "Коротко"))
    expect(mail.text_part.body.decoded).to(include("Открыть: http://www.example.com/n/"))
  end

  it "carries screenshots inside the letter" do
    image = newsletter.images.create!(content_type: "image/png", filename: "shot.png", data: "png", byte_size: 3)
    newsletter.update!(body_ru: "<div>x</div><img src=\"/newsletter_images/#{image.id}\">")

    mail = described_class.issue(delivery)

    expect(mail.attachments.map(&:filename)).to(eq(["shot.png"]))
    expect(mail.attachments.first).to(be_inline)
    expect(mail.html_part.body.decoded).to(include("cid:"))
  end

  it "builds a sample exactly like the real letter, marked as a test" do
    mail = described_class.sample(delivery)

    expect(mail.to).to(eq([user.email]))
    expect(mail.subject).to(eq("[Test] Новости"))
    expect(mail.html_part.body.decoded.scan(%r{http://www\.example\.com/n/}).size).to(eq(2))
    expect(mail["List-Unsubscribe"].value).to(match(%r{/unsubscribe/}))
  end
end
