# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ConcisedMarkup do
  it "drops the number the Ministry prints before every sense but the first" do
    expect(described_class.definition("7.數目大於零的。與「負」相對。")).to(
      eq("數目大於零的。與「負」相對。")
    )
    expect(described_class.definition("10. 姓。")).to(eq("姓。"))
  end

  it "keeps a number inside the definition" do
    expect(described_class.definition("直徑約21.6公分。")).to(eq("直徑約21.6公分。"))
  end

  it "cuts the list of similar words the Ministry appends after a triangle" do
    expect(described_class.definition("古代拼音法。　△反切")).to(eq("古代拼音法。"))
    expect(described_class.definition("雄性動物的腺體。 △前列腺")).to(eq("雄性動物的腺體。"))
  end

  it "leaves nothing of a definition that was only a cross-reference" do
    expect(described_class.definition("△獐")).to(be_nil)
  end

  it "keeps the collocation and drops the similar word glued to it" do
    expect(described_class.chip("油漆刷　△刷子")).to(eq("油漆刷"))
    expect(described_class.chip("二姊 △姊姊")).to(eq("二姊"))
  end

  it "tells a list of synonyms from a collocation and from a sentence" do
    expect(described_class.synonym_list?("姑媽、姑母", :collocation)).to(be(true))
    expect(described_class.synonym_list?("天然煤氣、天然瓦斯", :sentence)).to(be(true))
    expect(described_class.synonym_list?("牙刷、鞋刷，都要洗。", :sentence)).to(be(false))
    expect(described_class.synonym_list?("油漆刷", :collocation)).to(be(false))
  end
end
