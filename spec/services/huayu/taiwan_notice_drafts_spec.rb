# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Draft notices" do
  before { stub_notice_drafts }

  after { unstub_notice_drafts }

  let(:notices) { Huayu::TaiwanNotices }

  it "keeps a draft in the file but out of everything the service hands out" do
    expect(notices.drafts.map(&:id)).to(eq(["unsure"]))
    expect(notices.all.map(&:id)).to(eq(["ready"]))
    expect(notices.find("unsure")).to(be_nil)
    expect(notices.situations).to(eq(["health"]))
    expect(notices.sentences).not_to(include(NoticeDrafts::DRAFT_LINE))
  end

  it "leaves a draft out of the sitemap and the offline pack" do
    sitemap = Site::Sitemap.new(origin: "https://example.test").paths_for("pages")
    expect(sitemap).to(include("/notices/health"))
    expect(sitemap).not_to(include("/notices/school"))

    section = Offline::Sections.find("taiwan")
    expect(Offline::Pages.new(section).call.paths).not_to(include("/notices/school"))
  end

  it "never stores a draft line in the sentence corpus" do
    ContentSource.create!(
      slug: Huayu::NoticeImporter::SOURCE,
      name: "社區公告範本",
      license_commercial: true,
      register: :official,
      enabled: true,
      enabled_for_admins: true,
      attribution: "TaiwanCards."
    )

    Huayu::NoticeImporter.new.call

    expect(Lexeme.exists?(kind: :sentence, text: NoticeDrafts::PUBLISHED_LINE)).to(be(true))
    expect(Lexeme.exists?(kind: :sentence, text: NoticeDrafts::DRAFT_LINE)).to(be(false))
  end
end

RSpec.describe "Draft notices on the mock test", :no_auth do
  it "cannot reach a sign block, which is written from the exam bank alone" do
    drafts = Huayu::TaiwanNotices.drafts.flat_map(&:sentences)
    signs = MockExam::Bank
      .all
      .select(&:sign?)
      .flat_map { |block| [block.sign.title, *block.sign.lines, block.sign.foot] }
      .compact

    expect(signs & drafts).to(be_empty)
  end
end
