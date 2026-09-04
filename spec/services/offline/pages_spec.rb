# frozen_string_literal: true

require "rails_helper"

RSpec.describe Offline::Pages do
  def paths_for(id) = described_class.new(Offline::Sections.find(id)).call.paths

  RESTRICTED = %w[
    /textbook
    /stories
    /exams
    /course
    /desk
    /desks
    /study
    /profile
    /progress
    /reader
    /pronunciation
    /writing
    /search
    /help
    /mistakes
    /placement
    /plan
  ]
    .freeze

  it "collects no page that an account is needed for" do
    Offline::Sections.ids.each do |id|
      offending = paths_for(id).select { |path|
        RESTRICTED.any? { |gated| path == gated || path.start_with?("#{gated}/") }
      }

      expect(offending).to(be_empty, "#{id} would carry #{offending.first(3).join(", ")}")
    end
  end

  it "leaves the language prefix to the builder" do
    expect(paths_for("core")).to(all(start_with("/")))
    expect(paths_for("core").grep(%r{\A/(en|ru)/})).to(be_empty)
  end

  it "asks for no page twice inside one pack" do
    paths = paths_for("reference")

    expect(paths.uniq.size).to(eq(paths.size))
  end

  it "takes only the sentences pinned to the level it belongs to" do
    section = Offline::Sections.find("tocfl-novice1")
    entries = described_class.new(section).call.entries
    sentences = entries.select { |entry| entry.kind == "sentence" }
    position = SentenceProfile::TOCFL_LEVELS.index("Novice1") + 1
    expected = SentenceProfile.where(tocfl_exact: true, tocfl_index: position).count

    expect(sentences.size).to(eq([expected, described_class::SENTENCE_LIMIT].min))
  end

  it "gives every search entry a page to open" do
    described_class.new(Offline::Sections.find("grammar")).call.then do |result|
      expect(result.entries.map(&:path)).to(all(be_in(result.paths)))
    end
  end
end
