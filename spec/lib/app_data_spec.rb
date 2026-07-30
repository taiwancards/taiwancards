# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppData do
  around do |example|
    original = ENV["DATA_ROOT"]
    example.run
    ENV["DATA_ROOT"] = original
  end

  it "reads from data/ when DATA_ROOT is unset" do
    ENV.delete("DATA_ROOT")

    expect(described_class.root).to(eq(Rails.root.join("data")))
    expect(described_class).not_to(be_external)
    expect(described_class.path("huayu/x.json").to_s).to(eq(Rails.root.join("data/huayu/x.json").to_s))
  end

  it "falls through to dict_and_corpora for downloaded material" do
    ENV.delete("DATA_ROOT")

    expect(described_class.path("dictionaries/makemeahanzi").to_s)
      .to(eq(Rails.root.join("dict_and_corpora/dictionaries/makemeahanzi").to_s))
  end

  it "reads from DATA_ROOT when it is set" do
    ENV["DATA_ROOT"] = "/var/data"

    expect(described_class.root.to_s).to(eq("/var/data"))
    expect(described_class).to(be_external)
    expect(described_class.path("huayu/x.json").to_s).to(eq("/var/data/huayu/x.json"))
  end

  it "falls back to the repo copy when DATA_ROOT has no such file" do
    ENV["DATA_ROOT"] = "/var/data"

    expect(described_class.path("huayu/taiwan_everyday.json").to_s)
      .to(eq(Rails.root.join("data/huayu/taiwan_everyday.json").to_s))
  end

  it "still reports the DATA_ROOT path when no copy exists anywhere" do
    ENV["DATA_ROOT"] = "/var/data"

    expect(described_class.path("nothing/here.json").to_s).to(eq("/var/data/nothing/here.json"))
  end

  it "never falls back when resolving a write target" do
    ENV["DATA_ROOT"] = "/var/data"

    expect(described_class.target_path("huayu").to_s).to(eq("/var/data/huayu"))
  end

  it "keeps audio on the media root, and on DATA_ROOT once deployed" do
    ENV.delete("DATA_ROOT")
    expect(described_class.media_path("moe_audio").to_s).to(eq(Rails.root.join("media/moe_audio").to_s))

    ENV["DATA_ROOT"] = "/var/data"
    expect(described_class.media_path("moe_audio").to_s).to(eq("/var/data/moe_audio"))
  end
end
