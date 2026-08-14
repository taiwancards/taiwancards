# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ReadingStories do
  let(:path) { Rails.root.join("tmp/spec-reading-stories-#{SecureRandom.hex(4)}.json") }

  after { path.delete if path.exist? }

  def write(texts)
    path.dirname.mkpath
    path.write(JSON.generate({"texts" => texts}))
  end

  def story(overrides = {})
    {
      "slug" => "night-market",
      "category" => "everyday",
      "title" => "逛夜市",
      "level_tag" => "A2",
      "lines" => [
        {
          "zh" => "我們去夜市。",
          "en" => "We're going to the night market.",
          "ru" => "Мы идём на ночной рынок."
        },
        {"zh" => "人很多。", "en" => "There are a lot of people.", "ru" => "Народу много."}
      ]
    }.merge(overrides)
  end

  it "loads a text as a restricted reading text with its translations" do
    write([story])

    expect(described_class.new(path:).call).to(include(written: 1, texts: 1))

    text = ReadingText.find_by!(title: "逛夜市")
    expect(text.kind).to(eq("story"))
    expect(text).to(be_restricted)
    expect(text.lines).to(eq(["我們去夜市。", "人很多。"]))
    expect(text.translations(:ru)).to(eq(["Мы идём на ночной рынок.", "Народу много."]))
    expect(text.category).to(eq("everyday"))
  end

  it "writes nothing twice and reports no drift once loaded" do
    write([story])

    expect(described_class.new(path:)).to(be_drift)
    described_class.new(path:).call
    expect(described_class.new(path:).call).to(include(written: 0, unchanged: 1))
    expect(described_class.new(path:)).not_to(be_drift)
  end

  it "drops texts that left the file and keeps the reader's own texts" do
    write([story])
    described_class.new(path:).call
    mine = ReadingText.create!(kind: :article, title: "My text", body: "我去學校", source: "manual")

    write([story("slug" => "other", "title" => "別的")])
    expect(described_class.new(path:).call).to(include(dropped: 1))

    expect(ReadingText.where(kind: :story).pluck(:title)).to(eq(["別的"]))
    expect(mine.reload).to(be_present)
  end

  it "ignores rows with an unknown category or no lines" do
    write([story("category" => "songs"), story("slug" => "empty", "title" => "空", "lines" => [])])

    expect(described_class.new(path:).call).to(include(texts: 0))
  end
end
