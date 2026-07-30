# frozen_string_literal: true

require "rails_helper"

RSpec.describe News::PtsFetcher do
  let(:feed) { Rails.root.join("spec/fixtures/files/pts_rss.xml").read }

  it "imports headlines as unrestricted news texts with attribution" do
    result = described_class.new.call(body: feed)

    expect(result[:created]).to(eq(2))
    text = ReadingText.news.find_by(source_url: "https://news.pts.org.tw/article/000001")
    expect(text.title).to(eq("台北捷運今天起延長營運時間"))
    expect(text.author).to(eq("公視 PTS"))
    expect(text.restricted).to(be(false))
    expect(text.attribution).to(eq(I18n.t("reader.attribution_pts")))
  end

  it "strips the HTML out of the summary and normalises simplified characters" do
    described_class.new.call(body: feed)

    text = ReadingText.find_by(source_url: "https://news.pts.org.tw/article/000001")
    expect(text.body).to(include("延長營運時間"))
    expect(text.body).not_to(include("<p>"))
    expect(text.body).to(include("從今天起"))
  end

  it "does not re-import an article it already has" do
    described_class.new.call(body: feed)

    expect { described_class.new.call(body: feed) }.not_to(change(ReadingText, :count))
  end

  it "reports an error instead of raising when the feed is unreachable" do
    result = described_class.new.call(body: "")

    expect(result[:error]).to(eq("unreachable"))
  end
end
