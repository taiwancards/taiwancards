# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::RadicalImporter do
  it "imports canonical radicals and links characters via variant normalization" do
    create(:lexeme, :character, text: "海", data: {"radical" => "氵"})
    create(:lexeme, :character, text: "打", data: {"radical" => "扌"})
    create(:lexeme, :character, text: "一", data: {"radical" => "一"})

    result = described_class.new.call

    expect(result[:radicals]).to(eq(214))
    expect(result[:unmatched]).to(be_empty)

    water = Lexeme.find_by!(kind: :radical, text: "水")
    expect(water.data["number"]).to(eq(85))
    expect(Lexeme.find_by(text: "海").data["radical_canonical"]).to(eq("水"))
    expect(Lexeme.find_by(text: "海").data["radical_number"]).to(eq(85))
    expect(Lexeme.find_by(text: "打").data["radical_canonical"]).to(eq("手"))
  end
end
