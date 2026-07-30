# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::AxisNorms do
  before { described_class.instance_variable_set(:@data, norms) }
  after { described_class.reset! }

  let(:norms) do
    {
      "tone" => {"p50" => 1.15, "spread" => 0.49, "p90" => 2.83},
      "initial" => {"p50" => 0.0, "spread" => 1.0, "p90" => 2.0}
    }
  end

  it "gives a typical native a high mark rather than punishing the shape of the statistic" do
    expect(described_class.score("tone", 1.15)).to(be >= 90)
  end

  it "puts a rival syllable well below" do
    rival = 1.15 + (2.9 * 0.49)

    expect(described_class.score("tone", rival)).to(be_within(6).of(35))
  end

  it "stays strictly decreasing so ranking survives" do
    scores = [0.0, 0.5, 1.15, 1.6, 2.6, 4.0].map { |z| described_class.score("tone", z) }

    expect(scores).to(eq(scores.sort.reverse))
    expect(scores.uniq.length).to(eq(scores.length))
  end

  it "reads a signed axis the same way, since it uses the magnitude" do
    expect(described_class.score("initial", -2.0)).to(eq(described_class.score("initial", 2.0)))
  end

  it "falls back to the raw magnitude for an axis it has never measured" do
    expect(described_class.score("unheard_of", 0.0)).to(be > described_class.score("unheard_of", 5.0))
  end

  describe "#typical?" do
    it "accepts what a native usually produces" do
      expect(described_class.typical?("tone", 1.15)).to(be(true))
    end

    it "refuses what sits far outside their range" do
      expect(described_class.typical?("tone", 4.0)).to(be(false))
    end
  end
end
