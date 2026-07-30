# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Corpus reference data" do
  describe Huayu::WordSketch do
    it "indexes every head in the file" do
      expect(described_class).to(be_available)
      expect(described_class.size).to(be >= 5_000)
    end

    it "returns relations ordered by the declared grammar, not by hash order" do
      result = described_class.for("喝")
      names = result.relations.map(&:name)

      expect(result).to(be_any)
      expect(names).to(include("resultative", "aspect"))
      expect(names).to(eq(names.sort_by { |name| described_class::RELATIONS.index(name) || 99 }))
    end

    it "ranks the strongest collocate first" do
      relation = described_class.for("喝").relations.find { |row| row.name == "resultative" }

      expect(relation.collocates.first.text).to(eq("完"))
      expect(relation.collocates.map(&:score)).to(eq(relation.collocates.map(&:score).sort.reverse))
    end

    it "honours the requested limit" do
      expect(described_class.for("喝", limit: 2).relations.map { |row| row.collocates.length }).to(all(be <= 2))
    end

    it "is empty for a word the corpus never saw often enough" do
      expect(described_class.for("鬱鬱寡歡")).not_to(be_any)
      expect(described_class).not_to(be_covers("鬱鬱寡歡"))
    end
  end

  describe Huayu::PhoneticSeries do
    it "keeps only series that hold together in Middle Chinese" do
      expect(described_class.all).to(be_present)
      expect(described_class.all.map(&:regularity)).to(all(be >= 0.5))
    end

    it "finds the series a character belongs to" do
      series = described_class.containing("泡")

      expect(series.component).to(eq("包"))
      expect(series.members).to(include("抱", "跑", "袍"))
    end

    it "reports the modern payoff separately from the historical class" do
      series = described_class.containing("泡")

      expect(series.payoff).to(eq(1.0))
      expect(series.percent).to(eq(100))
      expect(series).to(be_reliable)
      expect(series).not_to(be_diverged)
    end

    it "flags a series that was regular then and is not now" do
      diverged = described_class.all.select(&:diverged?)

      expect(diverged).to(be_present)
      expect(diverged).to(all(satisfy { |row| row.regularity >= row.payoff }))
    end
  end

  describe Huayu::ConfusableCharacters do
    it "pairs characters that share their rarest component" do
      expect(described_class.for("清")).to(include("晴", "請"))
      expect(described_class.for("買")).to(include("賣"))
    end

    it "never returns the character itself" do
      expect(described_class.for("清")).not_to(include("清"))
    end

    it "can be narrowed to a pool for quiz distractors" do
      picks = described_class.distractors("清", count: 2, pool: %w[晴 貓 狗])

      expect(picks).to(eq(["晴"]))
    end
  end

  describe Huayu::MoeRevised do
    it "indexes the file sparsely so the whole dictionary costs almost no memory" do
      expect(described_class).to(be_available)
      expect(described_class.blocks).to(be_between(100, 5_000))
    end

    it "finds a headword at either end of the sorted file" do
      expect(described_class.for("一")).to(be_any)
      expect(described_class.for("鬱")).to(be_any)
    end

    it "returns senses with their part of speech and reading" do
      result = described_class.for("咖啡")

      expect(result).to(be_any)
      expect(result.senses.first.gloss).to(be_present)
    end

    it "is empty for something it does not list" do
      expect(described_class.for("ZZZ")).not_to(be_any)
    end
  end
end
