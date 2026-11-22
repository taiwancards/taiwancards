# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::CharacterEnricher do
  let(:path) { Rails.root.join("tmp/spec-etymology-structure-#{SecureRandom.hex(4)}.json") }
  let(:enricher) { described_class.new(overrides: path) }

  before do
    path.dirname.mkpath
    path.write(
      JSON.generate(
        {
          "麵" => {"type" => "pictophonetic", "semantic" => "麥", "phonetic" => "面", "hint" => "wheat"},
          "華" => {"type" => "pictographic", "semantic" => nil, "phonetic" => nil, "hint" => "A flowering plant"},
          "起" => {"phonetic" => "巳"},
          "商" => {"type" => nil, "semantic" => nil, "phonetic" => nil, "hint" => nil},
          "千" => {"type" => "pictophonetic", "semantic" => "一", "phonetic" => "人"}
        }
      )
    )
  end

  after { path.delete if path.exist? }

  def character(text, etymology)
    Lexeme.create!(kind: :character, text: text, data: {"etymology" => etymology, "strokes" => 20}.compact)
  end

  it "puts the meaning part and the sound part of a character the right way round" do
    lexeme = character("麵", {"type" => "pictophonetic", "hint" => "face", "semantic" => "面", "phonetic" => "麥"})

    expect(enricher.repair_overrides).to(eq(1))
    expect(lexeme.reload.data["etymology"]).to(
      eq({"type" => "pictophonetic", "hint" => "wheat", "semantic" => "麥", "phonetic" => "面"})
    )
    expect(lexeme.data["strokes"]).to(eq(20))
  end

  it "drops the parts of a character that is a picture, not a compound" do
    lexeme = character("華", {"type" => "pictophonetic", "hint" => "ten", "semantic" => "十", "phonetic" => "艹"})

    enricher.repair_overrides

    expect(lexeme.reload.data["etymology"]).to(
      eq({"type" => "pictographic", "hint" => "A flowering plant"})
    )
  end

  it "changes nothing once the structure is right and leaves other characters alone" do
    character("麵", {"type" => "pictophonetic", "hint" => "face", "semantic" => "面", "phonetic" => "麥"})
    other = character("媽", {"type" => "pictophonetic", "hint" => "woman", "semantic" => "女", "phonetic" => "馬"})
    enricher.repair_overrides

    expect(enricher.repair_overrides).to(eq(0))
    expect(other.reload.data["etymology"]["semantic"]).to(eq("女"))
  end

  it "gives a structure to a character that had none" do
    lexeme = character("千", nil)

    expect(enricher.repair_overrides).to(eq(1))
    expect(lexeme.reload.data["etymology"]).to(
      eq({"type" => "pictophonetic", "semantic" => "一", "phonetic" => "人"})
    )
  end

  it "removes a structure the sources do not support" do
    lexeme = character("商", {"type" => "pictophonetic", "hint" => "bright", "semantic" => "冏", "phonetic" => "章"})

    expect(enricher.repair_overrides).to(eq(1))
    expect(lexeme.reload.data).not_to(have_key("etymology"))
    expect(enricher.repair_overrides).to(eq(0))
  end
end
