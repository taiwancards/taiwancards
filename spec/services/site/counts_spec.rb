# frozen_string_literal: true

require "rails_helper"

RSpec.describe Site::Counts do
  before { described_class.reset! }

  after { described_class.reset! }

  it "counts only unrestricted lexemes" do
    create(:lexeme, kind: :word, text: "免費", restricted: false)
    create(:lexeme, kind: :word, text: "限制", restricted: true)

    expect(described_class.compute).to(include(words: 1))
  end

  it "reports every advertised kind, even when empty" do
    expect(described_class.compute.keys).to(eq(described_class::KINDS))
  end

  it "counts each kind separately" do
    create(:lexeme, kind: :character, text: "學")
    create(:lexeme, kind: :radical, text: "子")
    create(:lexeme, kind: :word, text: "學生")

    expect(described_class.compute).to(include(characters: 1, radicals: 1, words: 1, collocations: 0))
  end

  it "answers from the cache once warmed" do
    with_cache do
      create(:lexeme, kind: :word, text: "第一")
      described_class.warm!
      create(:lexeme, kind: :word, text: "第二")

      expect(described_class.fetch).to(include(words: 1))
    end
  end

  it "recomputes after a reset" do
    with_cache do
      described_class.warm!
      create(:lexeme, kind: :word, text: "新的")
      described_class.reset!

      expect(described_class.fetch).to(include(words: 1))
    end
  end

  it "takes one query for every kind" do
    expect(count_queries { described_class.compute }.count).to(eq(1))
  end
end
