# frozen_string_literal: true

require "rails_helper"

RSpec.describe FontUrlCompiler do
  subject(:compiler) { described_class.new(Rails.application.assets) }

  let(:css) { "@font-face { src: url(\"/fonts/tw-kai-core.woff2\") format('woff2'); }" }

  def with_base(url)
    allow(ENV).to(receive(:[]).and_call_original)
    allow(ENV).to(receive(:[]).with("ASSETS_BASE_URL").and_return(url))
    FontAssets.forget_stamps!
  end

  after { FontAssets.forget_stamps! }

  it "leaves the stylesheet alone when the app serves its own fonts" do
    with_base(nil)

    expect(compiler.compile(nil, css.dup)).to(eq(css))
  end

  it "sends the stylesheet to the shared origin when there is one" do
    with_base("https://assets.example.test")

    expect(compiler.compile(nil, css.dup)).to(include(FontAssets.url_for("tw-kai-core.woff2")))
  end

  it "rewrites every face in the file, not only the first" do
    with_base("https://assets.example.test")
    two = "#{css}\n#{css.sub("core", "full")}"

    expect(compiler.compile(nil, two).scan("https://assets.example.test").length).to(eq(2))
  end

  it "touches nothing that is not a font" do
    with_base("https://assets.example.test")
    other = "background: url(\"/assets/flag.svg\");"

    expect(compiler.compile(nil, other.dup)).to(eq(other))
  end
end
