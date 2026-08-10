# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SentenceBrackets do
  describe ".hollow?" do
    it "sees an empty pair" do
      expect(described_class).to(be_hollow("北港（）古稱笨港。"))
      expect(described_class).to(be_hollow("馬祖南竿機場（，）位於南竿島東側。"))
      expect(described_class).to(be_hollow("昔日以礦業繁盛（、）一時。"))
    end

    it "leaves a pair with content alone" do
      expect(described_class).not_to(
        be_hollow("離八德區最近的機場為臺灣桃園國際機場（IATA：TPE）。")
      )
    end
  end

  describe ".beheaded?" do
    it "sees a sentence that lost its subject" do
      expect(described_class).to(be_beheaded("（）是高雄的一個分區。"))
    end

    it "leaves a sentence whose empty pair sits inside" do
      expect(described_class).not_to(be_beheaded("北港（）古稱笨港。"))
    end
  end

  describe ".clean" do
    it "removes an empty pair" do
      expect(described_class.clean("北港（）古稱笨港。")).to(eq("北港古稱笨港。"))
    end

    it "removes a pair holding only separators" do
      expect(described_class.clean("馬祖南竿機場（，）位於南竿島東側。")).to(
        eq("馬祖南竿機場位於南竿島東側。")
      )
    end

    it "removes a bracket left unmatched" do
      expect(described_class.clean("公司「」在2008年證實。")).to(eq("公司在2008年證實。"))
    end

    it "collapses separators the removal doubled" do
      expect(described_class.clean("他來了，（），我走了。")).to(eq("他來了，我走了。"))
    end

    it "keeps a balanced pair that carries content" do
      text = "離八德區最近的機場為臺灣桃園國際機場（IATA：TPE）。"
      expect(described_class.clean(text)).to(eq(text))
    end
  end

  describe ".unbalanced?" do
    it "sees an unclosed quote" do
      expect(described_class).to(be_unbalanced("古人說：「十年寒窗無人問。"))
    end

    it "accepts nesting" do
      expect(described_class).not_to(be_unbalanced("他說：「這是《書》。」"))
    end
  end
end
