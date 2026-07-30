# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentSource do
  let(:admin) { User.create!(email: "a@example.com", password: "password123", admin: true) }
  let(:reader) { User.create!(email: "r@example.com", password: "password123", admin: false) }

  let(:source) do
    described_class.create!(
      slug: "test_src",
      license_commercial: true,
      name: "Test",
      enabled: true,
      enabled_for_admins: true,
      attribution: "Test source."
    )
  end

  def sentence!(text)
    lexeme = Lexeme.new(kind: :sentence, text:)
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  def word!(text)
    Lexeme.create!(kind: :word, text:)
  end

  describe "what a source may own" do
    it "lets words exist with no source at all" do
      expect { word!("捷運") }.not_to(raise_error)
      expect(word!("悠遊卡").content_sources).to(be_empty)
    end

    it "refuses to store a sentence without one" do
      orphan = Lexeme.new(kind: :sentence, text: "這是一個句子。")
      expect(orphan).not_to(be_valid)
      expect(orphan.errors[:content_sources]).to(be_present)
    end
  end

  describe "the kill switch" do
    before do
      sentence!("開快車，難免出車禍。")
      word!("車禍")
    end

    it "hides the source's sentences from everyone when switched off" do
      source.update!(enabled: false, enabled_for_admins: false)
      expect(Lexeme.visible_to(reader).where(kind: :sentence)).to(be_empty)
      expect(Lexeme.visible_to(admin).where(kind: :sentence)).to(be_empty)
    end

    it "keeps them for admins when only the public switch is cleared" do
      source.update!(enabled: false, enabled_for_admins: true)
      expect(Lexeme.visible_to(reader).where(kind: :sentence)).to(be_empty)
      expect(Lexeme.visible_to(admin).where(kind: :sentence).map(&:text)).to(eq(["開快車，難免出車禍。"]))
    end

    it "never hides words, whichever way the switches are set" do
      source.update!(enabled: false, enabled_for_admins: false)
      expect(Lexeme.visible_to(reader).where(kind: :word).map(&:text)).to(include("車禍"))
      expect(Lexeme.visible_to(nil).where(kind: :word).map(&:text)).to(include("車禍"))
    end

    it "shows everything again once the source is switched back on" do
      source.update!(enabled: false)
      expect(Lexeme.visible_to(reader).where(kind: :sentence)).to(be_empty)
      source.update!(enabled: true)
      expect(Lexeme.visible_to(reader).where(kind: :sentence).count).to(eq(1))
    end
  end

  describe "attribution as a condition of the license" do
    it "refuses to enable a source that has nothing to attribute with" do
      source = described_class.new(slug: "nameless", license_commercial: true, name: "Nameless", enabled: true)
      expect(source).not_to(be_valid)
      expect(source.errors[:attribution]).to(be_present)
    end

    it "asks nothing of a source we only measure, since it is never shown" do
      source = described_class.new(slug: "measured", license_commercial: false, name: "Measured", enabled: true)
      expect(source).to(be_valid)
    end

    it "allows a fully switched-off source to have none" do
      source = described_class.new(
        slug: "parked",
        license_commercial: true,
        name: "Parked",
        enabled: false,
        enabled_for_admins: false
      )
      expect(source).to(be_valid)
    end

    it "gives every shipped source an attribution string" do
      described_class.delete_all
      ContentSources::Importer.new.call
      missing = described_class.where(enabled: true).reject { |source| source.attribution.present? }
      expect(missing.map(&:slug)).to(be_empty)
    end
  end

  describe "what the license decides on its own" do
    before do
      described_class.delete_all
      ContentSources::Importer.new.call
    end

    it "ships sources that commercial use is not cleared for" do
      expect(described_class.measurement_only).to(be_any)
    end

    it "publishes none of them, whichever way the switches are set" do
      described_class.measurement_only.update_all(enabled: true, enabled_for_admins: true)

      expect(described_class.measurement_only.select(&:publishable?)).to(be_empty)
      expect(described_class.measurement_only.select(&:carries_content?)).to(be_empty)
    end

    it "shows none of them to an admin either" do
      described_class.measurement_only.update_all(enabled: true, enabled_for_admins: true)
      admin = User.create!(email: "boss@example.com", password: "password123", admin: true)

      visible = described_class.visible_to(admin).pluck(:slug)

      expect(visible).not_to(include(*described_class.measurement_only.pluck(:slug)))
    end
  end
end
