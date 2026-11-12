# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::TemplateStore do
  let(:root) { Dir.mktmpdir }
  let(:store) { described_class.new(File.join(root, "pronunciation")) }

  before do
    FileUtils.mkdir_p(File.join(root, "pronunciation", "templates", "taiwan"))
    FileUtils.mkdir_p(File.join(root, "huayu"))
    File.write(File.join(root, "pronunciation", "templates", "taiwan", "ma1.json"), JSON.generate({"key" => "ma1"}))
    File.write(File.join(root, "huayu", "starter_track.json"), JSON.generate({"secret" => true}))
    File.write(File.join(root, "pronunciation", "x1.json"), JSON.generate({"secret" => true}))
  end

  after { FileUtils.remove_entry(root, true) }

  it "reads a syllable template under one of its norms" do
    expect(store.template("ma1")).to(eq("key" => "ma1"))
  end

  it "lists every norm the store knows" do
    expect(described_class::NORMS).to(
      contain_exactly("taiwan", "taiwan_word", "taiwan_wi", "taiwan_wm", "taiwan_wf")
    )
  end

  it "refuses a norm that climbs out of the templates directory without touching the disk" do
    allow(File).to(receive(:exist?).and_call_original)

    expect(store.template("starter_track", "../../huayu")).to(be_nil)
    expect(File).not_to(have_received(:exist?))
  end

  it "refuses a key that is not shaped like a syllable without touching the disk" do
    allow(File).to(receive(:exist?).and_call_original)

    expect(store.template("../x1")).to(be_nil)
    expect(store.template("../../../huayu/starter_track")).to(be_nil)
    expect(store.template({"x" => "1"})).to(be_nil)
    expect(File).not_to(have_received(:exist?))
  end

  it "answers a stray norm even when it names a real file" do
    expect(store.template("x1", "..")).to(be_nil)
  end
end
