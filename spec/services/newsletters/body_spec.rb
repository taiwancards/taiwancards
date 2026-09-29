# frozen_string_literal: true

require "rails_helper"

RSpec.describe Newsletters::Body do
  it "keeps formatting and drops anything executable" do
    html = "<div>Hi <strong>there</strong><script>alert(1)</script><a href=\"javascript:alert(1)\">x</a></div>"

    cleaned = described_class.clean(html)

    expect(cleaned).to(include("<strong>there</strong>"))
    expect(cleaned).not_to(include("script", "javascript"))
  end

  it "drops the file name caption Trix adds under an image, and the link around it" do
    html = <<~HTML
      <figure data-trix-attachment="{}" class="attachment attachment--preview"><a href="/newsletter_images/7"><img src="/newsletter_images/7" width="800" height="600"></a><figcaption class="attachment__caption"><span class="attachment__name">shot.png</span> 30 KB</figcaption></figure>
      <figure class="attachment"><img src="/newsletter_images/8"><figcaption class="attachment__caption attachment__caption--edited">The new screen</figcaption></figure>
    HTML

    cleaned = described_class.clean(html)

    expect(cleaned).not_to(include("shot.png", "<a "))
    expect(cleaned).to(include("The new screen", "src=\"/newsletter_images/7\""))
    expect(described_class.image_ids(cleaned)).to(eq([7, 8]))
  end
end
