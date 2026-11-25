# frozen_string_literal: true

require "rails_helper"

RSpec.describe StoredPath do
  describe ".readable" do
    it "turns percent-encoding back into the characters the learner saw" do
      expect(described_class.readable("/characters/%E9%9B%B6")).to(eq("/characters/零"))
      expect(described_class.readable("/dict/%E5%85%A7")).to(eq("/dict/內"))
    end

    it "keeps plain paths and their query strings as they are, decoded" do
      expect(described_class.readable("/grammar/zhe-na-na")).to(eq("/grammar/zhe-na-na"))
      expect(described_class.readable("/search?q=%E9%9B%B6")).to(eq("/search?q=零"))
    end

    it "keeps a locale prefix" do
      expect(described_class.readable("/ru/characters/%E9%9B%B6")).to(eq("/ru/characters/零"))
    end

    it "drops byte sequences that are not UTF-8 and leaves stray percent signs readable" do
      expect(described_class.readable("/dict/%FF%E5%85%A7")).to(eq("/dict/內"))
      expect(described_class.readable("/dict/%ZZ")).to(eq("/dict/%ZZ"))
    end

    it "falls back to the readable part when the limit cut an escape in half" do
      expect(described_class.readable("/characters/%E9%9B")).to(eq("/characters/"))
      expect(described_class.readable("/characters/%E9%9B%B")).to(eq("/characters/"))
      expect(described_class.readable("/characters/%E9%9B%")).to(eq("/characters/"))
      expect(described_class.readable("/characters/零%E9")).to(eq("/characters/零"))
    end

    it "strips control and bidirectional override characters a visitor could plant" do
      expect(described_class.readable("/dict/abc%E2%80%AEgpj.exe")).to(eq("/dict/abcgpj.exe"))
      expect(described_class.readable("/dict/a%0D%0Ab%00%E2%81%A6c")).to(eq("/dict/abc"))
    end
  end

  describe ".clip" do
    it "leaves a short path alone" do
      expect(described_class.clip("/dict/%E5%85%A7", 255)).to(eq("/dict/%E5%85%A7"))
    end

    it "never splits an escape or a character when it shortens" do
      path = "/c/a#{"%E9%9B%B6" * 40}"

      (200..255).each do |limit|
        clipped = described_class.clip(path, limit)

        expect(clipped.length).to(be <= limit)
        expect(clipped).to(match(/\A\/c\/a(?:%E9%9B%B6)*\z/))
        expect(Rack::Utils.unescape_path(clipped).force_encoding(Encoding::UTF_8)).to(be_valid_encoding)
      end
    end

    it "stops at a bounded number of escapes when the tail is junk" do
      expect(described_class.clip("/x/#{"%FF" * 20}", 30)).to(eq("/x/#{"%FF" * 5}"))
    end
  end

  it "stores activity paths cut at a character boundary" do
    event = ActivityEvent.record(
      user: create(:user),
      controller: "characters",
      action: "show",
      verb: "GET",
      path: "/characters/x#{"%E9%9B%B6" * 40}"
    )

    expect(event.path.length).to(be <= ActivityEvent::PATH_LIMIT)
    expect(event.path).to(end_with("%E9%9B%B6"))
  end
end
