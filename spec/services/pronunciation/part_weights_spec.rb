# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Weighting of parts a syllable does not have" do
  let(:weights) { Pronunciation::Acoustic::Weights }

  def shares_for(syllable, tone, present)
    weights.shares(weights.for_syllable(syllable, tone, present))
  end

  it "spreads the whole weight over the parts that exist" do
    {
      ["ju", 4] => %w[initial final tone],
      ["a", 1] => %w[final tone],
      ["gao", 1] => %w[initial final tone],
      ["xue", 2] => %w[initial medial final tone]
    }.each do |(syllable, tone), present|
      shares = shares_for(syllable, tone, present)

      expect(shares.keys).to(match_array(present))
      expect(shares.values.sum).to(be_within(0.001).of(1.0))
    end
  end

  it "gives an absent part no weight at all" do
    shares = shares_for("a", 1, %w[final tone])

    expect(shares).not_to(have_key("initial"))
    expect(shares).not_to(have_key("medial"))
  end

  describe "the percentages shown on the tiles" do
    let(:backend) { Pronunciation::AcousticBackend.new(store: instance_double(Pronunciation::TemplateStore)) }

    it "always add up to exactly a hundred" do
      [
        {"initial" => 0.155, "final" => 0.37, "tone" => 0.485},
        {"final" => 0.46, "tone" => 0.54},
        {"initial" => 0.1435, "medial" => 0.1435, "final" => 0.2765, "tone" => 0.4365}
      ].each do |shares|
        percentages = backend.send(:percentages, shares)

        expect(percentages.values.sum).to(eq(100))
        expect(percentages.keys).to(match_array(shares.keys))
      end
    end

    it "returns nothing to show when there is nothing measured" do
      expect(backend.send(:percentages, {})).to(be_empty)
    end
  end
end
