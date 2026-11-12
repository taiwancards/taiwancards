# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::VariantForms do
  def word(text, meaning)
    create(:lexeme, kind: :word, text:, meanings: {"en" => meaning})
  end

  it "puts the standard spelling of a Taiwan word first" do
    plain = word("台獨", "Taiwan independence")
    word("臺獨", "Taiwan independence")

    expect(described_class.new(user: nil).call(plain).map(&:text)).to(eq(%w[臺獨 台獨]))
  end

  it "keeps 臺 in front for a place in Taiwan" do
    plain = word("台北", "Taipei")
    word("臺北", "Taipei")

    expect(described_class.new(user: nil).call(plain).map(&:text)).to(eq(%w[臺北 台北]))
  end

  it "puts 台 first where the character has nothing to do with Taiwan" do
    plain = word("舞台", "stage")
    rich = word("舞臺", "stage")
    rich.senses.create!(position: 0, meanings: {"en" => "a stage"})

    expect(described_class.new(user: nil).call(plain).map(&:text)).to(eq(%w[舞台 舞臺]))
  end

  it "puts the counter spelling first for a word written three ways" do
    plain = word("櫃台", "counter")
    word("櫃臺", "counter")
    word("櫃檯", "counter")

    expect(described_class.new(user: nil).call(plain).map(&:text)).to(eq(%w[櫃檯 櫃台 櫃臺]))
  end

  it "pairs a whole-word variant and puts the Taiwan spelling first" do
    plain = word("手表", "wristwatch")
    word("手錶", "wristwatch")

    expect(described_class.new(user: nil).call(plain).map(&:text)).to(eq(%w[手錶 手表]))
  end

  it "keeps a whole-word pair from touching other words with the same characters" do
    expect(described_class.new(user: nil).spellings("黑板")).to(be_empty)
    expect(described_class.new(user: nil).spellings("表面")).to(be_empty)
  end

  it "keeps a word whose only spelling we hold out of the list" do
    lonely = word("臺北", "Taipei")

    expect(described_class.new(user: nil).call(lonely)).to(be_empty)
  end

  describe ".taiwan_twins" do
    it "returns the other spelling of a Taiwan word" do
      expect(described_class.taiwan_twins("台啤")).to(eq(["臺啤"]))
      expect(described_class.taiwan_twins("臺北盆地")).to(eq(["台北盆地"]))
    end

    it "returns nothing where 台 is a stage or a counter" do
      expect(described_class.taiwan_twins("舞台")).to(be_empty)
      expect(described_class.taiwan_twins("月臺")).to(be_empty)
      expect(described_class.taiwan_twins("一臺")).to(be_empty)
    end
  end

  describe "which 臺/台 means Taiwan" do
    taiwan = %w[
      臺灣
      臺北
      臺中
      臺南
      臺東
      臺灣積體電路製造股份有限公司
      台灣積體電路製造股份有限公司
      臺積電
      台積電
      臺電
      臺啤
      臺鐵
      臺大
      臺茶
      臺幣
      新臺幣
      臺菜
      臺式
      臺劇
      臺海
      臺妹
      臺客
      臺斤
      臺語
      臺獨
      臺股
      台人
      台生
      台版
      台資
      台企
      台籍
      台澎
      台美
      台日
      台韓
      台歐
      國台辦
      來臺
      訪臺
      首次訪臺
      在臺協會
      全臺
      返臺
      駐臺
      旅臺
      赴臺
      抵臺
      離臺
      對臺軍售
      親臺
      反臺
      挺臺
      援臺
      抗中保臺
      繞臺
      賣臺
      擾台
      滯臺中國人
      臺灣臺語
      駐德國台北代表處
      臺北101
      臺灣Pay
      臺茶18號
      臺1線
      台G
      上台北
    ]
    elsewhere = %w[
      平台
      舞台
      櫃台
      月台
      電台
      電視台
      天文台
      氣象台
      講台
      陽台
      吧台
      服務台
      流理台
      梳妝台
      看台
      擂台
      後台
      上台
      下台
      台上
      台下
      台詞
      背臺詞
      台階
      台燈
      一台車
      兩台iPad
      一臺3D電視
      台子
      台長
      台數
      臺地
      臺端
      臺鑒
      兄臺
      舞台劇
      平台經濟
      櫃台服務員
      月台層
      茅台酒
      仙台
      蒙台威爾第
      亭臺樓閣
      近水樓臺
      釣魚臺
      唱對台戲
      在台上
      台州
      五台山
    ]

    taiwan.each do |text|
      it "reads #{text} as a Taiwan word" do
        expect(described_class.new(user: nil).taiwan?(text)).to(be(true))
      end
    end

    elsewhere.each do |text|
      it "reads #{text} as a word about something other than Taiwan" do
        expect(described_class.new(user: nil).taiwan?(text)).to(be(false))
      end
    end
  end

  it "heads a Taiwan word the brief list never named with 臺" do
    plain = word("台海", "the Taiwan Strait")
    word("臺海", "the Taiwan Strait")

    expect(described_class.new(user: nil).call(plain).map(&:text)).to(eq(%w[臺海 台海]))
  end

  it "heads a verb-plus-Taiwan word with 臺" do
    plain = word("在台協會", "institute in Taiwan")
    word("在臺協會", "institute in Taiwan")

    expect(described_class.new(user: nil).call(plain).map(&:text)).to(eq(%w[在臺協會 在台協會]))
  end

  it "ranks each 臺/台 in a word on its own" do
    plain = word("台北電視台", "a Taipei TV station")
    word("臺北電視臺", "a Taipei TV station")
    word("臺北電視台", "a Taipei TV station")

    expect(described_class.new(user: nil).call(plain).first.text).to(eq("臺北電視台"))
  end

  it "gives the other spellings of a word with 臺 or 台" do
    expect(described_class.tai_twins("台啤")).to(eq(%w[臺啤]))
    expect(described_class.tai_twins("臺北電視台")).to(eq(%w[臺北電視臺 台北電視台]))
    expect(described_class.tai_twins("臺")).to(be_empty)
    expect(described_class.tai_twins("電視")).to(be_empty)
  end

  it "leaves single characters alone" do
    character = create(:lexeme, :character, text: "臺")
    create(:lexeme, :character, text: "台")

    expect(described_class.new(user: nil).call(character)).to(be_empty)
  end

  it "ignores a word without any variant character" do
    lexeme = word("電視", "television")

    expect(described_class.new(user: nil).call(lexeme)).to(be_empty)
  end
end
