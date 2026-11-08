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
    profile = Huayu::CharacterProfile.new(lexeme, user: nil)

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
    profile = Huayu::CharacterProfile.new(lexeme.reload, user: nil)

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

  it "keeps each language's translation when another language is applied" do
    lexeme = character("味", {"etymology" => {"hint" => "mouth"}})
    write({"味" => {"hint" => "рот"}})
    described_class.new(path:).call
    write({"味" => {"hint" => "miệng"}})
    described_class.new(path:, locale: "vi").call

    expect(lexeme.reload.data["etymology_i18n"]).to(eq({"ru" => {"hint" => "рот"}, "vi" => {"hint" => "miệng"}}))
    I18n.with_locale(:vi) { expect(Huayu::CharacterProfile.new(lexeme, user: nil).etymology_hint).to(eq("miệng")) }
  end

  it "translates the etymology of a word on the word page" do
    word = Lexeme.create!(kind: :word, text: "東西", data: {"etymology_text" => "\"thing; stuff\""})
    character("東", {"etymology_text" => "Pictogram."})
    write({"東西" => {"text" => "“đồ vật; thứ”"}})

    expect(described_class.new(path:, locale: "vi", kind: :word).call).to(include(written: 1))
    profile = Huayu::WordProfile.new(word.reload, user: nil)
    I18n.with_locale(:vi) { expect(profile.etymology).to(eq("“đồ vật; thứ”")) }
    I18n.with_locale(:ru) { expect(profile.etymology).to(eq("\"thing; stuff\"")) }
    expect(Lexeme.find_by(kind: :character, text: "東").data).not_to(have_key("etymology_i18n"))
  end

  it "replaces a wrong English etymology of a word on the English page" do
    word = Lexeme.create!(
      kind: :word,
      text: "衣服",
      data: {"etymology_text" => "From 衣, matching English E (“ecstasy”)."}
    )
    write({"衣服" => {"text" => "Compound of 衣 and 服."}})

    described_class.new(path:, locale: "en", kind: :word).call
    profile = Huayu::WordProfile.new(word.reload, user: nil)

    I18n.with_locale(:en) { expect(profile.etymology).to(eq("Compound of 衣 and 服.")) }
    expect(word.data["etymology_text"]).to(eq("From 衣, matching English E (“ecstasy”)."))
  end

  it "ignores entries whose fields are blank" do
    character("味", {"etymology" => {"hint" => "mouth"}})
    write({"味" => {"hint" => "  ", "text" => ""}})

    expect(described_class.new(path:).call).to(include(entries: 0))
    expect(described_class.new(path:)).not_to(be_drift)
  end
end
