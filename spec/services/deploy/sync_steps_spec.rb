# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe Deploy::SyncSteps do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("deploy:sync") }

  def step(name) = described_class::STEPS.find { |candidate| candidate.name == name }

  it "can tell for every step whether its sources changed" do
    described_class::STEPS.each do |step|
      expect(step.paths + step.media_paths).not_to(
        be_empty,
        "#{step.name} names no source file, so Deploy::SyncGuard cannot skip it and it would rewrite rows on every deploy"
      )
    end
  end

  it "names a task that exists for every step" do
    described_class::STEPS.each do |step|
      expect(Rake::Task.task_defined?(step.task)).to(be(true), "#{step.name} points at a missing #{step.task}")
    end
  end

  it "fingerprints code that exists" do
    described_class::STEPS.each do |step|
      step.code_paths.each { |path| expect(path).to(exist, "#{step.name} fingerprints a missing #{path}") }
    end
  end

  it "re-asserts the gloss overrides whenever a page importer can have overwritten them" do
    expect(step("gloss_overrides").paths).to(include(*described_class::CURATED_PAGE_SOURCES))
  end

  it "re-runs every step that reads a curated page file when one of them changes" do
    %w[ru_glosses collocation_meanings].each do |name|
      expect(step(name).paths).to(include(*described_class::CURATED_PAGE_SOURCES), "#{name} defers to the page files")
      expect(step(name).code).to(include("app/services/huayu/curated_glosses.rb"), "#{name} reads them through it")
    end
  end

  it "keeps the deploy list of curated pages the same as the one the services read" do
    expect(described_class::CURATED_PAGE_SOURCES).to(match_array(Huayu::CuratedGlosses::PATHS))
  end

  it "re-asserts the sentence store when another writer of sentence meanings changes" do
    expect(step("sentence_meanings").code).to(include("app/services/huayu/ru_enricher.rb"))
    expect(step("sentence_meanings").paths).to(include("huayu/ru_glosses.json"))
  end

  it "derives the register mix only when the sources that feed it change" do
    expect(step("register_mix").paths).to(include("content_sources.json"))
  end

  it "re-runs the page importers when the code they share changes" do
    %w[taiwan_everyday medicine games].each do |name|
      expect(step(name).code).to(
        include("app/services/huayu/curated_page_importer.rb", "app/services/lexemes/upserter.rb")
      )
    end
  end

  it "keeps a step that only warms apart from one that rewrites content" do
    expect(described_class::WARMING).to(match_array(%w[landing_counts syllable_index prune_activity google_scopes]))
    expect(described_class::ACCOUNT).to(match_array(described_class::WARMING + %w[admin_rights]))
    expect(described_class::ALWAYS.keys - described_class::WARMING).not_to(be_empty)
    expect(described_class::ALWAYS.keys).to(include(*described_class::ACCOUNT))
  end
end
