# frozen_string_literal: true

require "rails_helper"

RSpec.describe Intro::Map do
  let(:anchors) do
    Rails
      .root
      .glob("app/{views,helpers}/**/*.{slim,rb}")
      .flat_map { |file| file.read.lines.grep(/tour/) }
      .flat_map { |line| line.scan(/"([a-z][a-z0-9-]*)"/) }
      .flatten
      .to_set
  end

  it "loads the essential tour" do
    expect(described_class.essential).to(be_present)
  end

  it "keeps the mandatory tour short enough to finish in a minute" do
    expect(described_class.essential.length).to(be <= 10)
  end

  it "keeps the full guide under thirty steps" do
    expect(described_class.chapters.sum(&:length)).to(be <= 30)
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
      missing = wanted - anchors.to_a

      expect(missing).to(be_empty, "intro_map.yml points at anchors that no template renders: #{missing.join(", ")}")
    end
  end

  describe "every step that hands over to another page" do
    it "declares where the user lands" do
      handovers = described_class.all_steps.select(&:waits_for_click?)

      expect(handovers.map(&:lands_on)).to(all(be_present))
    end

    it "lands on a page the gate will then allow" do
      described_class.all_steps.select(&:waits_for_click?).each do |step|
        following = described_class.essential[described_class.essential.index(step).to_i + 1]
        next if following.nil? || following.path.blank?

        expect(following.path).to(eq(step.lands_on))
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
      kind: nil,
      interactive: nil,
      version: 1
    )
  end

  it "counts a hand-over step done when the user reaches the page it points at" do
    allow(Intro::Map).to(receive(:essential).and_return([handover, Intro::Map.essential.last]))
    user.update!(prefs: user.prefs.merge("intro_stage" => "pending", "intro_step" => "handover"))

    user.intro.arrived_at("/dict")

    expect(user.reload.intro_step).to(eq(Intro::Map.essential.last.id))
  end

  it "ignores arrivals anywhere else" do
    allow(Intro::Map).to(receive(:essential).and_return([handover, Intro::Map.essential.last]))
    user.update!(prefs: user.prefs.merge("intro_stage" => "pending", "intro_step" => "handover"))

    user.intro.arrived_at("/progress")

    expect(user.reload.intro_step).to(eq("handover"))
  end
end
