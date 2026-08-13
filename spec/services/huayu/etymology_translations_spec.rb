# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::EtymologyTranslations do
  let(:path) { Rails.root.join("tmp/spec-etymology-ru-#{SecureRandom.hex(4)}.json") }

  after { path.delete if path.exist? }

  def write(entries)
    path.dirname.mkpath
    path.write(JSON.generate(entries))
  end

  def character(text, data)
    Lexeme.create!(kind: :character, text: text, data: data)
  end

  it "stores the Russian etymology beside the English one" do
    lexeme = character(
      "檯",
      {"etymology" => {"hint" => "A wooden 木 platform 臺"}, "etymology_text" => "Phono-semantic compound."}
    )
    write(
      {"檯" => {"hint" => "деревянный помост 臺", "text" => "Фоноидеограмма (形聲)."}}
    )

    expect(described_class.new(path:).call).to(include(written: 1))
    expect(lexeme.reload.data["etymology"]["hint"]).to(eq("A wooden 木 platform 臺"))
    expect(lexeme.data.dig("etymology_i18n", "ru")).to(
      eq({"hint" => "деревянный помост 臺", "text" => "Фоноидеограмма (形聲)."})
    )
  end

  it "reads the Russian text on a Russian page and the English one otherwise" do
    lexeme = character(
      "味",
      {
        "etymology" => {"hint" => "mouth", "type" => "pictophonetic"},
        "etymology_text" => "Phono-semantic compound.",
        "etymology_i18n" => {"ru" => {"hint" => "рот", "text" => "Фоноидеограмма (形聲)."}}
      }
    )
    profile = Huayu::CharacterProfile.new(lexeme)

    I18n.with_locale(:ru) do
      expect(profile.etymology_hint).to(eq("рот"))
      expect(profile.etymology_text).to(eq("Фоноидеограмма (形聲)."))
      expect(profile.etymology_type).to(eq("фоноидеограмма"))
      expect(profile).to(be_etymology_translated)
    end

    I18n.with_locale(:en) do
      expect(profile.etymology_hint).to(eq("mouth"))
      expect(profile.etymology_text).to(eq("Phono-semantic compound."))
      expect(profile.etymology_type).to(eq("phono-semantic compound"))
      expect(profile).not_to(be_etymology_translated)
    end
  end

  it "falls back to the English etymology where no translation exists" do
    lexeme = character(
      "龘",
      {"etymology" => {"hint" => "flight of a dragon"}, "etymology_text" => "Ideogrammic compound."}
    )
    write({"檯" => {"hint" => "деревянный помост"}})
    described_class.new(path:).call
    profile = Huayu::CharacterProfile.new(lexeme.reload)

    I18n.with_locale(:ru) do
      expect(profile.etymology_hint).to(eq("flight of a dragon"))
      expect(profile.etymology_text).to(eq("Ideogrammic compound."))
      expect(profile).not_to(be_etymology_translated)
    end
  end

  it "writes nothing twice and reports no drift once applied" do
    character("味", {"etymology" => {"hint" => "mouth"}})
    write({"味" => {"hint" => "рот"}})

    expect(described_class.new(path:)).to(be_drift)
    described_class.new(path:).call
    expect(described_class.new(path:).call).to(include(written: 0, unchanged: 1))
    expect(described_class.new(path:)).not_to(be_drift)
  end

  it "ignores entries whose fields are blank" do
    character("味", {"etymology" => {"hint" => "mouth"}})
    write({"味" => {"hint" => "  ", "text" => ""}})

    expect(described_class.new(path:).call).to(include(entries: 0))
    expect(described_class.new(path:)).not_to(be_drift)
  end
end
