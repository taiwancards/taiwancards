# frozen_string_literal: true

require "rails_helper"

RSpec.describe Newsletters::EmailHtml do
  def render(html, images: {7 => "cid:seven"}) = described_class
    .new(html, image_src: -> (id) { images[id] }, link: -> (url) { "tracked:#{url}" })
    .call

  it "inlines styles, routes links through the tracker and swaps images for attachments" do
    html = render(
      "<h1>News</h1><div>See <a href=\"/ru/desk\">this</a></div><img src=\"/newsletter_images/7\" width=\"1200\" height=\"800\">"
    )

    expect(html).to(include("<h1 style=", "href=\"tracked:/ru/desk\"", "src=\"cid:seven\"", "width=\"544\""))
    expect(html).not_to(include("height="))
  end

  it "turns a link that stands alone on its line into a button and leaves other links as links" do
    html = render("<div><a href=\"/ru/desk\">Open</a><br></div><div>See <a href=\"/ru/desk\">this</a></div>")

    styles = html.scan(/<a href="tracked:\/ru\/desk" style="([^"]+)"/).flatten
    expect(styles.first).to(include("background:#111111", "text-decoration:none"))
    expect(styles.last).to(include("text-decoration:underline"))
  end

  it "leaves out an image that is not attached rather than linking to the app" do
    expect(render("<div>x</div><img src=\"/newsletter_images/9\">")).not_to(include("<img"))
  end
end
