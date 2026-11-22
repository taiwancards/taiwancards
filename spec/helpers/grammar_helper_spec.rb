# frozen_string_literal: true

require "rails_helper"

RSpec.describe GrammarHelper do
  let(:lesson) { Data.define(:head, :titles) { def title(locale) = titles[locale.to_s] } }

  def chip(title, locale) = helper.grammar_chip(lesson.new(head: "的", titles: {locale => title}), locale)

  it "splits a chip title on the em dash" do
    expect(chip("的 — possession", "en")).to(eq(["的", "possession"]))
  end

  it "splits a German chip title on the en dash" do
    expect(chip("的 – Besitz", "de")).to(eq(["的", "Besitz"]))
  end

  it "keeps a hyphenated title whole and labels it with the head" do
    expect(chip("Ja-Nein-Fragen", "de")).to(eq(["的", "Ja-Nein-Fragen"]))
  end

  it "quotes a German gloss with German quotation marks" do
    expect(helper.grammar_quote("„Ich trinke Tee.“", "de")).to(include("„Ich trinke Tee.“"))
    expect(helper.grammar_quote("I drink tea.", "de")).to(include("„I drink tea.“"))
  end

  it "quotes an Indonesian gloss with curly double quotation marks" do
    expect(helper.grammar_quote("Saya minum teh.", "id")).to(include("“Saya minum teh.”"))
  end

  it "recognizes a German gloss beside a Chinese example" do
    blocks = helper.send(:grammar_blocks, "Zum Beispiel: 我喜歡喝茶 — „Ich trinke gern Tee.“")

    expect(blocks).to(include([:example, "我喜歡喝茶", "„Ich trinke gern Tee.“"]))
  end
end
