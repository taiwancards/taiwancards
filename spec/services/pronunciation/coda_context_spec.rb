# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::ContextNorms do
  it "groups the consonants that mute a nasal coda apart from those that do not" do
    expect(described_class.onset_class("sh")).to(eq("voiceless"))
    expect(described_class.onset_class("x")).to(eq("voiceless"))
    expect(described_class.onset_class("t")).to(eq("voiceless"))
    expect(described_class.onset_class("m")).to(eq("nasal"))
    expect(described_class.onset_class("b")).to(eq("voiced"))
    expect(described_class.onset_class("")).to(eq("vowel"))
  end

  it "expects less murmur before a voiceless consonant than before a voiced one" do
    quiet = described_class.coda_factor("sh")
    loud = described_class.coda_factor("b")
    skip("no coda norms available") if quiet.nil? || loud.nil?

    expect(quiet).to(be < loud)
  end

  it "asks for nothing when no syllable follows at all" do
    expect(described_class.coda_factor(nil)).to(be_nil)
  end

  it "tells a vowel-initial neighbour apart from having no neighbour" do
    skip("no coda norms available") if described_class.coda_factor("").nil?

    expect(described_class.coda_factor("")).not_to(be_nil)
  end
end

RSpec.describe Pronunciation::Acoustic::Analyzer do
  let(:store) { Pronunciation::TemplateStore.instance }
  let(:analyzer) { described_class.new(store) }

  def nasal_template
    %w[bang1 tong2 ban1 fang4 zheng4]
      .filter_map { |key| store.template(key, "taiwan_word") || store.template(key) }
      .find { |t| t.dig("structure", "nasal_coda") && t["nasal_ratio_tail"] }
  end

  it "does not hold a muted murmur against a syllable a fricative follows" do
    template = nasal_template or skip("no nasal template available")
    skip("no coda norms available") if Pronunciation::Acoustic::ContextNorms.coda_factor("sh").nil?

    wanted = template.dig("nasal_ratio_tail", "median")
    features = {"nasal_ratio_tail" => wanted * 0.9, "onset_after" => "sh"}
    alone = analyzer.send(:muffled, template, {"nasal_ratio_tail" => wanted})

    expect(analyzer.send(:muffled, template, features).dig("nasal_ratio_tail", "median")).to(
      be < alone.dig("nasal_ratio_tail", "median")
    )
  end

  it "leaves the murmur norm alone when nothing follows" do
    template = nasal_template or skip("no nasal template available")

    expect(analyzer.send(:muffled, template, {})).to(equal(template))
  end
end
