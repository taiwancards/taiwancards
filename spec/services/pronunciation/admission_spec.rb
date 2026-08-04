# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Admission do
  it "runs the work and gives the seat back" do
    expect(described_class.take { :graded }).to(eq(:graded))
    expect(described_class.take { :graded }).to(eq(:graded))
  end

  it "gives the seat back even when the analysis blows up" do
    expect { described_class.take { raise "boom" } }.to(raise_error("boom"))

    expect(described_class.take { :graded }).to(eq(:graded))
  end

  it "turns the next arrival away rather than letting both crawl" do
    stub_const("#{described_class}::WAIT", 0.05)
    described_class.seats.acquire(described_class.seats.available_permits)

    begin
      expect(described_class.take { :graded }).to(eq(:busy))
    ensure
      described_class.seats.release(described_class::SEATS)
    end
  end

  it "keeps at least one seat even if the setting is nonsense" do
    expect(described_class.seats.available_permits).to(be >= 1)
  end
end
