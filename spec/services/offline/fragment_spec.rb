# frozen_string_literal: true

require "rails_helper"

RSpec.describe Offline::Fragment do
  def page(main_class, body = "<p>hi</p>")
    <<~HTML
      <!DOCTYPE html><html lang="en"><head><title>Title &amp; more</title></head>
      <body><header>bar</header><main class="#{main_class}">#{body}</main><footer>foot</footer></body></html>
    HTML
  end

  it "keeps only what sits inside main" do
    fragment = described_class.new(page("mx-auto max-w-3xl")).call

    expect(fragment.fetch("m")).to(eq("<p>hi</p>"))
  end

  it "unescapes the title" do
    fragment = described_class.new(page("max-w-3xl")).call

    expect(fragment.fetch("t")).to(eq("Title & more"))
  end

  it "drops the content security nonce" do
    fragment = described_class.new(page("max-w-3xl", "<script nonce=\"abc\">x</script>")).call

    expect(fragment.fetch("m")).to(eq("<script>x</script>"))
  end

  it "answers nothing for a page without a main element" do
    expect(described_class.new("<html><body>bare</body></html>").call).to(be_nil)
  end
end
