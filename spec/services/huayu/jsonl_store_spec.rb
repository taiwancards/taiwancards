# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::JsonlStore do
  let(:store) { Huayu::SentenceGlossStore }
  let(:scratch) { Pathname(Dir.mktmpdir) }
  let(:path) { scratch.join("sentence_glosses.jsonl") }

  before { allow(store).to(receive(:path).and_return(path)) }
  after { scratch.rmtree }

  def entry(text, en) = store::Entry.new(text:, en:, ru: nil, vi: nil)

  it "leaves the previous file whole when a rewrite breaks off" do
    store.write([entry("一", "one"), entry("二", "two")])
    before = path.read
    calls = 0
    allow(JSON).to(receive(:generate).and_wrap_original) do |original, *args|
      calls += 1
      raise IOError, "disk full" if calls == 2

      original.call(*args)
    end

    expect { store.put("三", en: "three", ru: nil) }.to(raise_error(IOError))
    expect(path.read).to(eq(before))
    expect(scratch.children).to(eq([path]))
  end

  it "replaces the file with the new content" do
    store.write([entry("一", "one")])
    store.put("二", en: "two", ru: nil)

    expect(store.read.map(&:text)).to(eq(%w[一 二]))
    expect(scratch.children).to(eq([path]))
  end
end
