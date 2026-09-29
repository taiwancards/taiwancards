# frozen_string_literal: true

require "rails_helper"

RSpec.describe Newsletter do
  it "writes to everyone who signed in with Google and has not unsubscribed, and always to the owner" do
    reader = create(:user, google_uid: "g-1")
    create(:user, google_uid: "g-2", newsletter_unsubscribed_at: 1.day.ago)
    create(:user, google_uid: nil)
    owner = create(:user, :admin, newsletter_unsubscribed_at: 1.day.ago)

    expect(described_class.recipients).to(contain_exactly(reader, owner))
  end

  it "is ready to send only with a subject and text in both languages" do
    newsletter = described_class.create!(subject_en: "News", body_en: "<div>Hi</div>", subject_ru: "Новости")

    expect(newsletter).not_to(be_complete)

    newsletter.update!(body_ru: "<div>Привет</div>")
    expect(newsletter).to(be_complete)
  end

  it "drops buttons whose link is not a web, mail or app address" do
    newsletter = described_class.new(
      buttons: [{"label_en" => "Bad", "url" => "javascript:alert(1)"}, {"label_en" => "Go", "url" => "/en/desk"}]
    )

    expect(newsletter.buttons_for("en")).to(eq([{label: "Go", url: "/en/desk"}]))
  end

  it "keeps at most three buttons and only the fields a button has" do
    newsletter = described_class.create!(
      buttons: Array.new(5) { |i| {"label_en" => "B#{i}", "url" => "/x", "evil" => "1"} }
    )

    expect(newsletter.buttons.size).to(eq(3))
    expect(newsletter.buttons.first.keys).to(contain_exactly("label_en", "url"))
    expect(newsletter.buttons_for("en").first).to(eq(label: "B0", url: "/x"))
    expect(newsletter.buttons_for("ru")).to(be_empty)
  end
end
