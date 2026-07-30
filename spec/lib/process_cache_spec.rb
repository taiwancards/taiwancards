# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessCache do
  subject(:cache) { described_class.new(ttl: 60, limit: 3) }

  it "computes a value once and serves it again" do
    calls = 0
    2.times { cache.fetch("k") { calls += 1 } }

    expect(calls).to(eq(1))
  end

  it "recomputes once the entry has expired" do
    cache = described_class.new(ttl: 0, limit: 3)
    calls = 0
    2.times { cache.fetch("k") { calls += 1 } }

    expect(calls).to(eq(2))
  end

  it "keeps entries apart by key" do
    cache.fetch("a") { 1 }
    cache.fetch("b") { 2 }

    expect(cache.fetch("a") { 9 }).to(eq(1))
    expect(cache.fetch("b") { 9 }).to(eq(2))
  end

  it "caches a false value rather than recomputing it" do
    calls = 0
    2.times { cache.fetch("k") { calls += 1 and false } }

    expect(calls).to(eq(1))
  end

  it "drops everything once the limit is reached so it cannot grow without bound" do
    4.times { |index| cache.fetch("k#{index}") { index } }

    expect(cache.size).to(be <= 3)
  end

  describe "#once" do
    it "answers true the first time and false afterward" do
      expect(cache.once("k")).to(be(true))
      expect(cache.once("k")).to(be(false))
    end

    it "answers true again after the window passes" do
      cache = described_class.new(ttl: 0, limit: 3)

      expect(cache.once("k")).to(be(true))
      expect(cache.once("k")).to(be(true))
    end
  end
end
