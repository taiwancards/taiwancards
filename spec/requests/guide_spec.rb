# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The full guide" do
  def rendered_nav = controller.view_context.taiwan_nav

  it "leads to every page the navigation offers, so it cannot fall behind" do
    get("/en/help")

    expect(response).to(have_http_status(:ok))
    expect(rendered_nav).not_to(be_empty)
    rendered_nav.each do |group|
      group[:items].each do |_icon, label, path|
        expect(response.body).to(include("href=\"#{path}\""), "the guide never mentions #{label} (#{path})")
      end
    end
  end

  it "names and describes every section" do
    get("/en/help")

    rendered_nav.each do |group|
      expect(response.body).to(include(group[:label]))
      expect(response.body).to(include(I18n.t("nav.group_lede.#{group[:id]}")))
    end
  end

  it "offers a walkthrough for the sections that have one" do
    get("/en/help")

    Intro::Map.chapters.each do |chapter|
      expect(response.body).to(include("/intro/chapter/#{chapter.id}"), "#{chapter.id} is unreachable")
    end
  end

  it "gives every chapter a home in some section" do
    claimed = NavHelper::GROUPS.flat_map { |group| group[:chapters] }

    expect(Intro::Map.chapters.map(&:id) - claimed).to(be_empty)
    expect(claimed - Intro::Map.chapters.map(&:id)).to(be_empty)
  end

  it "can start the short introduction again" do
    get("/en/help")

    expect(response.body).to(include(I18n.t("intro.guide.replay_cta")))
    expect(response.body).to(include("/intro/start"))
  end
end

RSpec.describe "The introduction" do
  it "shows a newcomer where to start, what to walk through, and where the rest of it is" do
    ids = Intro::Map.essential.map(&:id)

    expect(ids).to(eq(%w[welcome start_level course dictionary search new_deck display guide]))
    expect(Intro::Map.essential.first.path).to(eq("/desk"))
    expect(Intro::Map.essential.last.path).to(eq("/help"))
  end

  it "spends its middle on one page, so it is not a chain of redirects" do
    middle = Intro::Map.essential[1..-2]

    expect(middle.map(&:path).uniq).to(eq(["/menu"]))
    expect(middle.map(&:target)).to(all(be_present))
  end

  it "spotlights something that is really on the page for every anchored step" do
    anchors = Rails
      .root
      .glob("app/{views,helpers}/**/*.{slim,rb}")
      .flat_map { |file| file.read.lines.grep(/tour/) }
      .flat_map { |line| line.scan(/"([a-z][a-z0-9-]*)"/) }
      .flatten
      .to_set

    Intro::Map.all_steps.filter_map(&:target).uniq.each do |target|
      next if target.start_with?("nav-item-")

      expect(anchors).to(include(target), "no element carries data-tour=\"#{target}\"")
    end
  end
end
