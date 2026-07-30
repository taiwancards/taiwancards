# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pronunciation data arriving after boot" do
  let(:root) { Dir.mktmpdir("pron-arrival") }
  let(:source) { Rails.root.join("data/pronunciation") }

  before do
    skip("data/pronunciation is not in this checkout") unless source.exist?

    ENV["PRONUNCIATION_DATA_PATH"] = root
    Pronunciation::TemplateStore.reset!
    Pronunciation::Drills.reset!
  end

  after do
    ENV.delete("PRONUNCIATION_DATA_PATH")
    FileUtils.remove_entry(root)
    Pronunciation::TemplateStore.reset!
    Pronunciation::Drills.reset!
    Pronunciation::Acoustic::Syllables.load!
  end

  def deliver!
    Pronunciation::Sync::PAYLOAD.each do |entry|
      FileUtils.cp_r(source.join(entry).realpath.to_s, File.join(root, entry))
    end
  end

  it "reports itself unavailable while the disk is empty" do
    expect(Pronunciation::AcousticBackend.new.health["ok"]).to(be(false))
    expect(Pronunciation::Drills.instance.sections).to(be_empty)
    expect(Pronunciation::TemplateStore.instance.thresholds).to(be_empty)
  end

  it "picks the data up without a restart once it lands" do
    Pronunciation::AcousticBackend.new.health
    Pronunciation::Drills.instance.sections
    Pronunciation::TemplateStore.instance.thresholds
    Pronunciation::Acoustic::Syllables.all_keys

    deliver!

    expect(Pronunciation::AcousticBackend.new.health["ok"]).to(be(true))
    expect(Pronunciation::Drills.instance.sections).not_to(be_empty)
    expect(Pronunciation::TemplateStore.instance.thresholds).not_to(be_empty)
    expect(Pronunciation::Acoustic::Syllables.all_keys).not_to(be_empty)
  end

  it "stops returning a missing template once the template arrives" do
    store = Pronunciation::TemplateStore.new(root)
    expect(store.template("gao1")).to(be_nil)

    deliver!

    expect(store.template("gao1")).to(be_a(Hash))
  end
end
