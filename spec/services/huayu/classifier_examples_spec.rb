# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ClassifierExamples do
  let(:source) do
    ContentSource.create!(
      slug: "corpus",
      license_commercial: true,
      name: "Corpus",
      register: :colloquial,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Corpus."
    )
  end

  def noun(text)
    create(:lexeme, kind: :word, text:, meanings: {"en" => "m-#{text}"})
  end

  def sentence(text, *words)
    create(:lexeme, kind: :sentence, text:, score: 5, content_sources: [source]).tap do |row|
      words.each { |word| SentenceWord.create!(lexeme: word, sentence_id: row.id, gdex: 500) }
    end
  end

  it "quotes one sentence per noun and splits it around the counted phrase" do
    book = noun("書")
    sentence("我買了三本書。", book)
    sentence("他有兩本書。", book)

    examples = described_class.new.for_pairs([%w[本 書]], limit: 12)

    expect(examples.size).to(eq(1))
    expect(examples.first.highlight).to(match(/\A[三兩]本書\z/))
    expect(examples.first.noun).to(eq(book))
  end

  it "ignores sentences where the classifier does not count the noun" do
    book = noun("書")
    sentence("這本來是我的書。", book)

    expect(described_class.new.for_pairs([%w[本 書]], limit: 12)).to(be_empty)
  end

  it "compiles one pattern per pair however many sentences it scans" do
    book = noun("書")
    pen = noun("筆")
    30.times { |index| sentence("第#{index}句沒有量詞的書和筆。", book, pen) }
    service = described_class.new
    allow(service).to(receive(:pattern).and_call_original)

    service.for_pairs([%w[本 書], %w[枝 筆]], limit: 12)

    expect(service).to(have_received(:pattern).twice)
  end
end
