# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Corpus::SplitAnalysis do
  let(:store) { instance_double(Pronunciation::TemplateStore) }

  it "gives every analysis the split its purpose calls for" do
    expect(Pronunciation::Corpus::Ladder::DEFAULT_PART).to(eq("test"))
    expect(Pronunciation::Corpus::ReportCard::DEFAULT_PART).to(eq("test"))
    expect(Pronunciation::Corpus::ThresholdsBuilder::DEFAULT_PART).to(eq("dev"))
    expect(Pronunciation::Corpus::AxisNormsBuilder::DEFAULT_PART).to(eq("dev"))
    expect(Pronunciation::Corpus::SyllableQuality::DEFAULT_PART).to(eq("all"))
  end

  it "refuses to analyze an empty split" do
    allow(Pronunciation::Corpus::Tokens).to(receive(:keys).with("dev").and_return([]))

    expect { Pronunciation::Corpus::AxisNormsBuilder.new(store:, io: nil).call }.to(
      raise_error(RuntimeError, /no keys in the 'dev' split/)
    )
  end
end
