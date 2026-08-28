# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::PlaceImporter do
  let(:path) { Rails.root.join("spec/fixtures/files/taiwan_places.json") }

  after { Huayu::TextAnalyzer.reset_vocabulary! }

  def importer = described_class.new(path:)

  it "imports a district with its reading, gloss and the cities it belongs to" do
    result = importer.call
    lexeme = Lexeme.find_by(kind: :word, text: "板橋區")

    expect(result.imported).to(eq(3))
    expect(result.skipped).to(eq(1))
    expect(lexeme.readings).to(include("pinyin" => "bǎn qiáo qū", "zhuyin" => "ㄅㄢˇ ㄑㄧㄠˊ ㄑㄩ"))
    expect(lexeme.meanings["ru"]).to(include("Нового Тайбэя"))
    expect(lexeme.data["place"]).to(eq(%w[新北市]))
    expect(lexeme.data["pos"]).to(eq("N"))
    expect(lexeme.sources).to(include(described_class::SOURCE))
  end

  it "lists every city a repeated district name belongs to, largest first" do
    importer.call

    expect(Lexeme.find_by(kind: :word, text: "中正區").data["place"]).to(eq(%w[臺北市 基隆市]))
  end
end
