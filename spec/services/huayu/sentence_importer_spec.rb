# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SentenceImporter do
  let(:root) { Pathname(Dir.mktmpdir("sentences")) }
  let(:io) { StringIO.new }

  after { FileUtils.remove_entry(root) }

  def source(slug:, register:, commercial: true)
    ContentSource.create!(
      slug: slug,
      license_commercial: commercial,
      name: slug,
      register: register,
      attribution: "test",
      enabled: true,
      style_sample: true
    )
  end

  def write(slug, texts)
    root.join("#{slug}.json").write(JSON.generate(texts))
  end

  def run = described_class.new(root: root, io: io).call

  describe "rejection at import time" do
    it "keeps a well formed sentence" do
      source(slug: "corpus", register: :colloquial)
      write("corpus", ["今天天氣很好，我們去公園散步。"])

      stats = run

      expect(Lexeme.where(kind: :sentence).pluck(:text)).to(eq(["今天天氣很好，我們去公園散步。"]))
      expect(stats["corpus_new"]).to(eq(1))
    end

    it "never inserts a sentence with too little character variety" do
      source(slug: "corpus", register: :colloquial)
      write("corpus", ["哈哈哈哈哈哈哈哈"])

      stats = run

      expect(Lexeme.where(kind: :sentence).count).to(eq(0))
      expect(stats["corpus_junk"]).to(eq(1))
    end

    it "never inserts a sentence opening on a dangling particle" do
      source(slug: "corpus", register: :colloquial)
      write("corpus", ["的政府機關辦理相關業務"])

      run

      expect(Lexeme.where(kind: :sentence).count).to(eq(0))
    end

    it "counts junk separately from the character gate" do
      source(slug: "corpus", register: :colloquial)
      write("corpus", ["哈哈哈哈哈哈哈哈", "今天天氣很好，我們去公園散步。"])

      stats = run

      expect(stats["corpus_junk"]).to(eq(1))
      expect(stats["corpus_gate"]).to(eq(0))
      expect(stats["corpus_new"]).to(eq(1))
    end

    it "records every rejection in the log rather than dropping it silently" do
      source(slug: "corpus", register: :colloquial)
      write("corpus", ["哈哈哈哈哈哈哈哈"])

      run

      expect(io.string).to(include("junk"))
    end
  end

  describe "attribution" do
    it "attaches an existing sentence to a second source instead of duplicating it" do
      first = source(slug: "one", register: :colloquial)
      second = source(slug: "two", register: :literary)
      write("one", ["今天天氣很好，我們去公園散步。"])
      write("two", ["今天天氣很好，我們去公園散步。"])

      run

      sentence = Lexeme.find_by(kind: :sentence)
      expect(Lexeme.where(kind: :sentence).count).to(eq(1))
      expect(sentence.content_sources.ids).to(match_array([first.id, second.id]))
    end
  end

  describe "a corpus that commercial use is not cleared for" do
    let!(:measured) { source(slug: "measured", register: :internet, commercial: false) }

    before { create(:lexeme, kind: :word, text: "公園") }

    it "stores not one of its sentences" do
      write("measured", ["今天天氣很好，我們去公園散步。"])

      run

      expect(Lexeme.where(kind: :sentence)).to(be_empty)
    end

    it "counts its vocabulary so the statistics still see it" do
      write("measured", ["今天天氣很好，我們去公園散步。"])

      run

      expect(RegisterSample.where(content_source: measured).pluck(:text, :n)).to(include(["公園", 1]))
    end

    it "counts only words the dictionary already holds" do
      write("measured", ["今天天氣很好，我們去公園散步。"])

      run

      expect(RegisterSample.pluck(:text)).to(eq(["公園"]))
    end

    it "says plainly that it stored nothing" do
      write("measured", ["今天天氣很好，我們去公園散步。"])

      run

      expect(io.string).to(include("no sentence stored"))
    end

    it "starts its tally afresh on every run instead of doubling it" do
      write("measured", ["今天天氣很好，我們去公園散步。"])

      run
      described_class.new(root: root, io: StringIO.new).call

      expect(RegisterSample.where(content_source: measured).sum(:n)).to(eq(1))
    end

    it "still stores the sentences of a corpus that is cleared" do
      source(slug: "free", register: :colloquial)
      write("free", ["今天天氣很好，我們去公園散步。"])
      write("measured", ["另外一句話，這裡有公園。"])

      run

      expect(Lexeme.where(kind: :sentence).pluck(:text)).to(eq(["今天天氣很好，我們去公園散步。"]))
    end
  end
end
