# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The section navigation" do
  let(:markup) { Rails.root.join("app/views/shared/_subnav.html.slim").read }

  it "never clips the dropdown panels it contains" do
    container = markup.lines.find { |line| line.include?("mx-auto") }

    expect(container).not_to(
      match(/overflow-(x-|y-)?(auto|scroll|hidden)/),
      "a scroll or clip container here cuts off the open dropdown: CSS forces the other axis away from visible"
    )
  end

  it "fits narrow viewports by wrapping rather than by scrolling" do
    container = markup.lines.find { |line| line.include?("mx-auto") }

    expect(container).to(include("flex-wrap"))
  end
end
