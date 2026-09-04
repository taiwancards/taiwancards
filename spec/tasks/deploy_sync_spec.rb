# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "deploy:sync" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("deploy:sync") }

  it "can tell for every step whether its sources changed" do
    SYNC_STEPS.each do |step|
      sources = step[:paths].to_a + step[:media_paths].to_a

      expect(sources).not_to(
        be_empty,
        "#{step[:name]} names no source file, so Deploy::SyncGuard cannot skip it and it would " \
          "rewrite rows on every deploy"
      )
    end
  end

  it "re-asserts the gloss overrides whenever a page importer can have overwritten them" do
    step = SYNC_STEPS.find { |candidate| candidate[:name] == "gloss_overrides" }

    expect(step[:paths]).to(
      include(*CURATED_PAGE_SOURCES),
      "the page importers run earlier and overwrite meanings, so the overrides must go stale with them"
    )
  end

  it "re-runs every step that reads a curated page file when one of them changes" do
    %w[ru_glosses collocation_meanings].each do |name|
      step = SYNC_STEPS.find { |candidate| candidate[:name] == name }

      expect(step[:paths]).to(include(*CURATED_PAGE_SOURCES), "#{name} defers to the page files")
      expect(step[:code]).to(include("app/services/huayu/curated_glosses.rb"), "#{name} reads them through it")
    end
  end

  it "keeps the deploy list of curated pages the same as the one the services read" do
    expect(CURATED_PAGE_SOURCES).to(match_array(Huayu::CuratedGlosses::PATHS))
  end

  it "re-asserts the sentence store when another writer of sentence meanings changes" do
    step = SYNC_STEPS.find { |candidate| candidate[:name] == "sentence_meanings" }

    expect(step[:code]).to(
      include("app/services/huayu/ru_enricher.rb"),
      "the Russian gloss dictionary shares keys with short sentences, so the store has to reclaim them"
    )
    expect(step[:paths]).to(include("huayu/ru_glosses.json"))
  end

  it "names a task that exists for every step" do
    SYNC_STEPS.each do |step|
      expect(Rake::Task.task_defined?(step[:task])).to(be(true), "#{step[:name]} points at a missing #{step[:task]}")
    end
  end

  it "derives the register mix only when the sources that feed it change" do
    step = SYNC_STEPS.find { |candidate| candidate[:name] == "register_mix" }

    expect(step).to(be_present, "the heaviest step of the deploy must be guarded like every other one")
    expect(step[:paths]).to(include("content_sources.json"))
  end

  it "drops the derived counts whenever a step actually rewrote content" do
    body = Rails.root.join("lib/tasks/deploy.rake").read.split("task(sync: :environment)").last.split("desc(").first

    expect(body).to(include("ContentCache.clear"))
    expect(WARMING_STEPS).to(match_array(%w[landing_counts syllable_index prune_activity google_scopes]))
    expect(ALWAYS_STEPS.keys - WARMING_STEPS).not_to(
      be_empty,
      "if every always-step only warms, the cache drop can never fire"
    )
  end

  it "re-warms what it just cleared" do
    body = Rails.root.join("lib/tasks/deploy.rake").read.split("task(sync: :environment)").last.split("desc(").first
    drop = body[body.index("ContentCache.clear")..]

    expect(drop).to(include("Site::Counts.warm!"))
    expect(drop).to(include("Pronunciation::SyllableIndex.for"))
  end

  it "leaves the unguarded bulk fillers to a person running them on purpose" do
    body = Rails.root.join("lib/tasks/deploy.rake").read.split("task(sync: :environment)").last.split("desc(").first

    expect(body).not_to(
      include("deploy:fillers"),
      "deploy:sync must not invoke the whole filler list: those services already run as guarded steps"
    )
  end
end
