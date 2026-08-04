# frozen_string_literal: true

require "rails_helper"

RSpec.describe Onboarding::Path do
  let(:user) { create(:user, start_level: "zero") }

  def keys_for(level)
    described_class::TRACKS.fetch(level)
  end

  it "starts a complete beginner on the explanation, not on the drill" do
    first = described_class::STEPS.fetch(keys_for("zero").first)

    expect(first.key).to(eq("zhuyin_theory"))
    expect(first).to(be_theory)
    expect(first.route).to(eq(:practice_zhuyin_path))
  end

  it "alternates explanation and practice from the very start" do
    kinds = keys_for("zero").first(5).map { |key| described_class::STEPS.fetch(key).kind }

    expect(kinds).to(eq(%i[theory practice practice theory practice]))
  end

  it "explains the tones before asking anyone to hear them" do
    order = keys_for("zero")

    expect(order.index("tones_theory")).to(be < order.index("tones"))
    expect(described_class::STEPS.fetch("tones_theory").route).to(eq(:tones_path))
    expect(described_class::STEPS.fetch("tones").route).to(eq(:tones_drill_path))
  end

  it "ticks the reading off once the reader has actually opened it" do
    path = described_class.new(user)
    expect(path.steps.first).to(include(key: "zhuyin_theory", state: :current))

    user.record_practice_run!(:zhuyin_theory)

    expect(described_class.new(user.reload).steps.first).to(include(key: "zhuyin_theory", state: :done))
  end

  it "moves the marker on to the trainer once the reading is done" do
    user.record_practice_run!(:zhuyin_theory)
    steps = described_class.new(user).steps

    expect(steps.find { |step| step[:state] == :current }).to(include(key: "zhuyin"))
  end

  it "points every step at a route that exists" do
    described_class::STEPS.each_value do |step|
      expect(Rails.application.routes.url_helpers).to(respond_to(step.route), "#{step.key} → #{step.route}")
    end
  end

  it "names every step in both languages" do
    missing = described_class::TRACKS.values.flatten.uniq.flat_map do |key|
      %i[en ru].flat_map do |locale|
        %w[title body].filter_map do |field|
          "#{locale}.#{key}.#{field}" if I18n.t("onboarding.path.steps.#{key}.#{field}", locale:, default: "").blank?
        end
      end
    end

    expect(missing).to(be_empty)
  end
end
