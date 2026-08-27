# frozen_string_literal: true

require "rails_helper"

RSpec.describe LevelBadgesHelper do
  let!(:collection) do
    Collection.create!(kind: :tocfl, name: "TOCFL Band B · B1", level_tag: "B1", position: 4)
  end

  let!(:source) do
    ContentSource.create!(
      slug: "spoken",
      license_commercial: true,
      name: "Spoken",
      register: :colloquial,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Spoken."
    )
  end

  def word(text, data)
    create(:lexeme, kind: :word, text:, data:)
  end

  def composite(kind, text, data = {})
    lexeme = Lexeme.new(kind:, text:, data:, meanings: {"en" => "meaning"})
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  describe "#level_badges" do
    it "links a listed word to its level, marked so the list can point at it" do
      lexeme = word("有用", {"tbcl_grade" => 2, "tocfl_level" => "B1"})

      badges = helper.level_badges(lexeme, marks: true)

      expect(badges).to(include("TOCFL B1", "TBCL 2"))
      expect(badges).to(include("/tocfl/#{collection.id}?mark=%E6%9C%89%E7%94%A8#mark"))
      expect(badges).to(include("/tbcl/2?mark=%E6%9C%89%E7%94%A8#mark"))
    end

    it "names the novice levels the way the lists do" do
      expect(helper.level_badges(word("難喝", {"tocfl" => 2}))).to(include("≈TOCFL Novice 2"))
    end

    it "marks a level read off the pieces as approximate and does not link it" do
      badges = helper.level_badges(word("就學貸款", {"tbcl" => 5, "tocfl" => 6}))

      expect(badges).to(include("≈TBCL 5", "≈TOCFL B2"))
      expect(badges).not_to(include("href"))
    end

    it "prefers the official grade over the one derived from the characters" do
      expect(helper.level_badges(word("腎臟", {"tbcl_grade" => 5, "tbcl" => 6}))).to(include("TBCL 5"))
    end

    it "treats full coverage as exact for a sentence, which is on no list of its own" do
      sentence = composite(:sentence, "他很有用。")
      profile = SentenceProfile.create!(lexeme: sentence, difficulty: 1, tbcl_index: 3, tbcl_exact: true)

      badges = helper.level_badges(sentence, profile:)

      expect(badges).to(include("TBCL 3"))
      expect(badges).to(include("/tbcl/3"))
    end

    it "keeps a collocation approximate even when every word of it is covered" do
      collocation = composite(:collocation, "邊關")
      profile = SentenceProfile.create!(lexeme: collocation, difficulty: 1, tbcl_index: 2, tbcl_exact: true)

      badges = helper.level_badges(collocation, profile:)

      expect(badges).to(include("≈TBCL 2"))
      expect(badges).not_to(include("href"))
    end

    it "says nothing where neither list nor pieces place the entry" do
      expect(helper.level_badges(word("邊關", {}))).to(eq(""))
    end

    it "caps how many pieces a link may carry" do
      sentence = composite(:sentence, "一二三四五六七八", {"segments" => %w[一 二 三 四 五 六 七 八]})
      profile = SentenceProfile.create!(lexeme: sentence, difficulty: 1, tbcl_index: 4, tbcl_exact: true)

      badges = helper.level_badges(sentence, profile:, marks: true)

      expect(CGI.unescape(badges[/mark=[^&"#]+/])).to(eq("mark=#{%w[一 二 三 四 五 六].join(",")}"))
    end
  end
end
