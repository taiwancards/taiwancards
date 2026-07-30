# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Responsive markup" do
  VIEWS = Rails.root.glob("app/views/**/*.html.slim").freeze
  NARROWEST_PHONE = 320

  def lines_of(path) = path.read.lines.map(&:rstrip)

  describe "tables" do
    it "keeps every table inside a horizontally scrollable container" do
      offenders = VIEWS.flat_map do |path|
        lines = lines_of(path)
        lines.each_with_index.filter_map do |line, index|
          next unless line.match?(/^\s*table[\s.\[]/)

          window = lines[[0, index - 3].max...index].join(" ")
          "#{path.relative_path_from(Rails.root)}:#{index + 1}" unless window.include?("overflow-x-auto")
        end
      end

      expect(offenders).to(be_empty)
    end
  end

  describe "grids" do
    it "never asks a phone to render four or more columns without a breakpoint" do
      offenders = VIEWS.flat_map do |path|
        lines_of(path).each_with_index.filter_map do |line, index|
          bare = line.gsub(/\b(?:sm|md|lg|xl|2xl):grid-cols-\d+/, "")
          next unless bare.match?(/(?:^|[.\s"'])grid-cols-(?:[4-9]|\d{2,})\b/)

          "#{path.relative_path_from(Rails.root)}:#{index + 1}"
        end
      end

      expect(offenders).to(be_empty)
    end
  end

  describe "fixed widths" do
    it "never hard-codes a width wider than the narrowest phone" do
      offenders = VIEWS.flat_map do |path|
        lines_of(path).each_with_index.flat_map do |line, index|
          line.scan(/\bmin-w-\[(\d+)px\]|\bw-\[(\d+)px\]/).flatten.compact.filter_map do |px|
            "#{path.relative_path_from(Rails.root)}:#{index + 1} (#{px}px)" if px.to_i > NARROWEST_PHONE
          end
        end
      end

      expect(offenders).to(be_empty)
    end
  end

  describe "the mobile tab bar" do
    it "clears the iOS home indicator" do
      expect(Rails.root.join("app/views/shared/_bottom_nav.html.slim").read).to(
        include("env(safe-area-inset-bottom)")
      )
    end

    it "gives every tab a touch target of at least 44px" do
      nav = Rails.root.join("app/views/shared/_bottom_nav.html.slim").read
      minimum = nav[/min-h-(\d+)/, 1].to_i * 4

      expect(minimum).to(be >= 44)
    end

    it "hides itself once there is room for the desktop header" do
      expect(Rails.root.join("app/views/shared/_bottom_nav.html.slim").read).to(include("md:hidden"))
    end
  end

  describe "the layout" do
    it "reserves room under the content for the mobile tab bar" do
      expect(Rails.root.join("app/views/layouts/application.html.slim").read).to(
        match(/pb-24\s+md:pb-16|pb-24.*md:pb-16/)
      )
    end

    it "opts into the full viewport on notched devices" do
      expect(Rails.root.join("app/views/layouts/application.html.slim").read).to(include("viewport-fit=cover"))
    end

    it "sizes the page by dynamic viewport height so mobile browser chrome cannot clip it" do
      expect(Rails.root.join("app/views/layouts/application.html.slim").read).to(include("min-h-dvh"))
    end
  end
end
