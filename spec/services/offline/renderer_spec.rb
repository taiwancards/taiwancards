# frozen_string_literal: true

require "rails_helper"

RSpec.describe Offline::Renderer do
  subject(:renderer) { described_class.new }

  it "renders an open page as a guest would see it" do
    html = renderer.call("/hanzi", :en)

    expect(html).to(include("<main"))
    expect(html).not_to(include("csrf-token"))
  end

  it "refuses a page that only an account may open" do
    expect { renderer.call("/desk", :en) }.to(raise_error(described_class::Refused, %r{/en/desk answered 302}))
  end

  it "refuses a page that answers with a session of its own" do
    allow(renderer).to(receive(:personal?).and_return(true))

    expect { renderer.call("/hanzi", :en) }.to(raise_error(described_class::Refused, /answered with a session/))
  end

  it "asks for the page in the locale it was given" do
    expect(renderer.call("/hanzi", :ru)).to(include("lang=\"ru\""))
  end
end
