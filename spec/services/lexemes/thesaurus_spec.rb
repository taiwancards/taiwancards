# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::Thesaurus do
  let(:frequency) { class_double(Huayu::WordFrequency) }
  let(:service) { described_class.new(frequency:) }

  def word(text, data = {})
    create(:lexeme, kind: :word, text:, data:, meanings: {"en" => text})
  end

  before do
    word("逐一")
    word("不再")
    word("頻頻")
  end

  it "shows the distributional groups when the head is frequent enough" do
    allow(frequency).to(receive(:adjusted).and_return(described_class::MIN_ADJUSTED_PER_MILLION))
    head = word("一一", {"synonyms" => ["逐一"], "antonyms" => ["不再"], "related" => ["頻頻"]})

    result = service.call(head)

    expect(result.groups["synonyms"].map(&:text)).to(eq(["逐一"]))
    expect(result.groups["related"].map(&:text)).to(eq(["頻頻"]))
    expect(result).to(be_distributional)
  end

  it "drops the distributional groups when the head is too rare to support them" do
    allow(frequency).to(receive(:adjusted).and_return(0.0))
    head = word("䕒", {"synonyms" => ["逐一"], "related" => ["頻頻"], "collocates" => ["逐一"]})

    result = service.call(head)

    expect(result.groups["synonyms"].map(&:text)).to(eq(["逐一"]))
    expect(result.groups["related"]).to(be_empty)
    expect(result.groups["collocates"]).to(be_empty)
    expect(result).not_to(be_distributional)
  end

  it "keeps dictionary relations for a rare head because they are not distributional" do
    allow(frequency).to(receive(:adjusted).and_return(0.0))
    head = word("䦧牆之禍", {"synonyms" => ["逐一"], "antonyms" => ["不再"]})

    result = service.call(head)

    expect(result).to(be_any)
    expect(result.groups["antonyms"].map(&:text)).to(eq(["不再"]))
  end

  it "reports the evidence behind the entry" do
    allow(frequency).to(receive(:adjusted).and_return(42.5))

    expect(service.call(word("測試", {"related" => ["頻頻"]})).evidence).to(eq(42.5))
  end

  it "returns the empty result when nothing resolves" do
    allow(frequency).to(receive(:adjusted).and_return(100.0))

    expect(service.call(word("空白"))).not_to(be_any)
  end
end
