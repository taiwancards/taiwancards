# frozen_string_literal: true

require "rails_helper"

RSpec.describe Intro::Map do
  def nav_item?(target)
    slug = target.to_s.delete_prefix("nav-item-")
    return false if slug == target.to_s

    Rails.application.routes.recognize_path("/#{slug.tr("-", "/")}", method: :get).present?
  rescue StandardError
    false
  end

  let(:anchors) do
    literal = Rails
      .root
      .glob("app/{views,helpers}/**/*.{slim,rb}")
      .flat_map { |file| file.read.lines.grep(/tour/) }
      .flat_map { |line| line.scan(/"([a-z][a-z0-9-]*)"/) }
      .flatten
      .to_set

    literal
  end

  it "loads the essential tour" do
    expect(described_class.essential).to(be_present)
  end

  it "has no step pretending to be newer than the map itself" do
    expect(described_class.all_steps.map(&:version).max).to(be <= described_class.version)
  end

  it "has no way to announce itself to someone who already finished" do
    expect(described_class).not_to(respond_to(:newer_than))
    expect(Intro::Progress.instance_methods).not_to(include(:unseen))
  end

  it "keeps the mandatory tour short enough to finish in a minute" do
    expect(described_class.essential.length).to(be <= 10)
  end

  it "keeps every chapter of the guide short" do
    described_class.chapters.each do |chapter|
      expect(chapter.length).to(be <= 6, "#{chapter.id} asks for too much in one sitting")
    end
  end

  it "gives every chapter a way through on a phone and on a desktop" do
    described_class.chapters.each do |chapter|
      Intro::Map::VIEWPORTS.each do |viewport|
        shown = chapter.steps.select { |step| step.shown_on?(viewport) }
        expect(shown).not_to(be_empty, "#{chapter.id} has nothing to show on #{viewport}")
      end
    end
  end

  it "gives every step a unique id inside its scope" do
    described_class.chapters.each do |chapter|
      expect(chapter.steps.map(&:id).uniq.length).to(eq(chapter.length))
    end

    expect(described_class.essential.map(&:id).uniq.length).to(eq(described_class.essential.length))
  end

  describe "every declared path" do
    it "resolves to a route the application serves" do
      paths = described_class.all_steps.filter_map(&:path).uniq

      unroutable = paths.reject { |path| Rails.application.routes.recognize_path(path, method: :get) rescue false }

      expect(unroutable).to(be_empty, "unroutable paths in intro_map.yml: #{unroutable.join(", ")}")
    end
  end

  describe "every declared anchor" do
    it "exists as a data-tour attribute somewhere in the views" do
      wanted = described_class.all_steps.filter_map(&:target).uniq
      missing = wanted.reject { |target| anchors.include?(target) || nav_item?(target) }

      expect(missing).to(be_empty, "intro_map.yml points at anchors that no template renders: #{missing.join(", ")}")
    end
  end

  describe "every step that waits for a tap" do
    it "points at something to tap" do
      described_class.all_steps.select(&:waits_for_click?).each do |step|
        expect(step.target).to(be_present, "#{step.scope}/#{step.id} waits for a tap on nothing")
      end
    end

    it "sends the reader to a page the application serves when the tap navigates" do
      described_class.all_steps.filter_map(&:lands_on).uniq.each do |path|
        landed = begin
          Rails.application.routes.recognize_path(path, method: :get)
        rescue StandardError
          false
        end

        expect(landed).to(be_truthy, "#{path} is not a page")
      end
    end
  end

  describe "every step" do
    it "has a title and a body in both locales" do
      missing = []

      I18n.available_locales.each do |locale|
        described_class.all_steps.each do |step|
          %w[title body].each do |part|
            key = "#{step.i18n_key}.#{part}"
            missing << "#{locale}: #{key}" unless I18n.exists?(key, locale)
          end
        end
      end

      expect(missing).to(be_empty, "untranslated intro copy: #{missing.first(8).join(", ")}")
    end
  end

  describe "every chapter" do
    it "has a title and a summary in both locales" do
      missing = []

      I18n.available_locales.each do |locale|
        described_class.chapters.each do |chapter|
          %w[title summary].each do |part|
            key = "#{chapter.i18n_key}.#{part}"
            missing << "#{locale}: #{key}" unless I18n.exists?(key, locale)
          end
        end
      end

      expect(missing).to(be_empty, "untranslated chapter copy: #{missing.first(8).join(", ")}")
    end
  end
end

RSpec.describe Intro::Progress do
  let(:user) { create(:user) }
  let(:handover) do
    Intro::Map::Step.new(
      id: "handover",
      chapter: nil,
      path: "/desk",
      target: "search",
      advance: "click",
      lands_on: "/dict",
      interactive: nil,
      only: nil,
      version: 1
    )
  end

  it "counts a hand-over step done when the user reaches the page it points at" do
    allow(Intro::Map).to(receive(:essential).and_return([handover, Intro::Map.essential.last]))
    user.update!(prefs: user.prefs.merge("intro_stage" => "running", "intro_step" => "handover"))

    user.intro.arrived_at("/dict")

    expect(user.reload.intro_step).to(eq(Intro::Map.essential.last.id))
  end

  it "ignores arrivals anywhere else" do
    allow(Intro::Map).to(receive(:essential).and_return([handover, Intro::Map.essential.last]))
    user.update!(prefs: user.prefs.merge("intro_stage" => "running", "intro_step" => "handover"))

    user.intro.arrived_at("/progress")

    expect(user.reload.intro_step).to(eq("handover"))
  end
end
