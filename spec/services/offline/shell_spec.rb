# frozen_string_literal: true

require "rails_helper"

RSpec.describe Offline::Shell do
  let(:html) do
    <<~HTML
      <!DOCTYPE html><html lang="en"><head><title>Whatever</title>
      <meta name="csrf-token" content="secret">
      <link rel="canonical" href="https://example.test/x">
      <link rel="stylesheet" href="/assets/app-abc.css">
      <script type="importmap" nonce="n1">{"imports":{}}</script>
      <link rel="modulepreload" href="/assets/application-def.js">
      <script type="module" nonce="n1">import "application"</script>
      </head><body><main class="max-w-5xl"><p>page</p></main></body></html>
    HTML
  end

  subject(:shell) { described_class.new(html).call }

  it "reports the width of the rendered layout" do
    expect(shell.fetch("w")).to(eq("medium"))
  end

  it "leaves a slot where the page content goes" do
    expect(shell.fetch("s")).to(include(described_class::MAIN_SLOT))
    expect(shell.fetch("s")).not_to(include("<p>page</p>"))
  end

  it "leaves slots for the asset tags of the running deploy" do
    expect(shell.fetch("s")).to(include(described_class::CSS_SLOT, described_class::JS_SLOT))
    expect(shell.fetch("s")).not_to(include("/assets/app-abc.css", "modulepreload"))
  end

  it "drops the session and page specific tags" do
    expect(shell.fetch("s")).not_to(include("csrf-token", "canonical", "nonce"))
  end

  it "answers nothing when the layout carries no main element" do
    expect(described_class.new("<html><body>bare</body></html>").call).to(be_nil)
  end
end
