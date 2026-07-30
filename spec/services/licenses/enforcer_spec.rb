# frozen_string_literal: true

require "rails_helper"

RSpec.describe Licenses::Enforcer do
  def source(slug, commercial:, statistics_only: false)
    ContentSource.create!(
      slug: slug,
      name: slug.titleize,
      register: :colloquial,
      attribution: slug,
      license_commercial: commercial,
      statistics_only: statistics_only,
      sentences_count: 100
    )
  end

  def sentence(text, sources)
    create(:lexeme, kind: :sentence, text: text, content_sources: sources)
  end

  let(:free) { source("free_corpus", commercial: true) }
  let(:paid_only) { source("paid_only", commercial: false) }
  let(:measured) { source("measured", commercial: true, statistics_only: true) }

  it "drops a sentence that only a non-commercial source carries" do
    doomed = sentence("只有非商業來源。", [paid_only])

    described_class.new.call

    expect(Lexeme.where(id: doomed.id)).to(be_empty)
  end

  it "keeps a sentence a commercial source also carries" do
    shared = sentence("兩個來源都有。", [free, paid_only])

    described_class.new.call

    expect(shared.reload).to(be_persisted)
  end

  it "drops a sentence carried only by a statistics-only source, even a commercial one" do
    doomed = sentence("只用來統計。", [measured])

    described_class.new.call

    expect(Lexeme.where(id: doomed.id)).to(be_empty)
  end

  it "leaves words and characters alone whatever their source" do
    word = create(:lexeme, kind: :word, text: "測試", content_sources: [paid_only])

    described_class.new.call

    expect(word.reload).to(be_persisted)
  end

  it "takes the dependent rows with it" do
    doomed = sentence("有附屬資料。", [paid_only])
    SentenceProfile.create!(lexeme: doomed, source_ids: [paid_only.id])

    described_class.new.call

    expect(SentenceProfile.where(lexeme_id: doomed.id)).to(be_empty)
  end

  it "zeroes the sentence tally of every source it no longer keeps anything for" do
    paid_only
    measured
    free

    described_class.new.call

    expect(paid_only.reload.sentences_count).to(eq(0))
    expect(measured.reload.sentences_count).to(eq(0))
    expect(free.reload.sentences_count).to(eq(100))
  end

  it "reports what it did and converges on a second run" do
    sentence("第一次就刪掉。", [paid_only])

    first = described_class.new.call
    second = described_class.new.call

    expect(first[:sentences_dropped]).to(eq(1))
    expect(second[:sentences_dropped]).to(eq(0))
  end
end
