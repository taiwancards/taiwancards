# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Corpus::Judged do
  let(:owner) { create(:user, restricted_content: true) }

  def kept(key:, overall:, level:, tone: nil, verdict: nil, rejected: [])
    row = PronunciationRecording.create!(
      user: owner,
      text: "字",
      syllable_keys: [key],
      syllables: [
        {
          "key" => key,
          "index" => 0,
          "char" => "字",
          "level" => level,
          "overall" => overall,
          "cells" => {"tone" => tone || overall}
        }
      ],
      audio: "bytes"
    )
    row.rate!(verdict, rejected: rejected) if verdict
    row
  end

  it "reports nothing while no recording has been rated" do
    kept(key: "hao3", overall: 90, level: "green")

    expect(described_class.new.call["n"]).to(be_zero)
  end

  it "counts what the native accepted and rejected" do
    6.times { kept(key: "hao3", overall: 90, level: "green", verdict: "accepted") }
    5.times { kept(key: "shi4", overall: 40, level: "red", verdict: "rejected") }

    expect(described_class.new.call).to(include("n" => 11, "accepted" => 6, "rejected" => 5))
  end

  it "measures how well the overall score tells the two apart" do
    6.times { |i| kept(key: "hao3", overall: 90 + i, level: "green", verdict: "accepted") }
    6.times { |i| kept(key: "shi4", overall: 30 + i, level: "red", verdict: "rejected") }

    expect(described_class.new.call.dig("cells", "overall", "auc")).to(eq(1.0))
  end

  it "proposes a cut that admits no more wrong syllables than asked" do
    10.times { |i| kept(key: "hao3", overall: 80 + i, level: "green", verdict: "accepted") }
    10.times { |i| kept(key: "shi4", overall: 40 + i, level: "red", verdict: "rejected") }

    expect(described_class.new.call.dig("cells", "overall", "cuts", 0.1, "admits")).to(be <= 10.0)
  end

  it "names the syllables where a green verdict was too kind" do
    6.times { kept(key: "shi4", overall: 90, level: "green", verdict: "rejected") }
    5.times { kept(key: "hao3", overall: 90, level: "green", verdict: "accepted") }

    expect(described_class.new.call.dig("disagreements", "lenient")).to(eq({"shi4" => 6}))
  end

  it "names the axis that was weakest where the native disagreed" do
    6.times { kept(key: "shi4", overall: 90, level: "green", tone: 55, verdict: "rejected") }

    expect(described_class.new.call.dig("blamed", "lenient")).to(eq({"tone" => 6}))
  end

  it "leaves out the syllables of a rejected word nobody pinned the blame on" do
    row = PronunciationRecording.create!(
      user: owner,
      text: "好事",
      syllable_keys: %w[hao3 shi4],
      syllables: [
        {"key" => "hao3", "index" => 0, "level" => "green", "overall" => 90, "cells" => {}},
        {"key" => "shi4", "index" => 1, "level" => "green", "overall" => 88, "cells" => {}}
      ],
      audio: "bytes"
    )
    row.rate!("rejected")

    expect(described_class.new.call["n"]).to(be_zero)
  end
end
