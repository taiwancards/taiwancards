# frozen_string_literal: true

require "rails_helper"

RSpec.describe HanziHelper do
  describe "#mark_script" do
    it "wraps each run of characters so the Taiwanese font stack applies to it" do
      expect(helper.mark_script("Words like 自由 and 民主"))
        .to(eq("Words like <span lang=\"zh-TW\">自由</span> and <span lang=\"zh-TW\">民主</span>"))
    end

    it "leaves the surrounding script alone, so Latin and Cyrillic keep their own face" do
      expect(helper.mark_script("no characters here")).to(eq("no characters here"))
      expect(helper.mark_script("совсем без иероглифов")).to(
        eq("совсем без иероглифов")
      )
    end

    it "escapes the text around the characters" do
      expect(helper.mark_script("<b>x</b> 自由")).to(eq("&lt;b&gt;x&lt;/b&gt; <span lang=\"zh-TW\">自由</span>"))
    end

    it "returns an empty string for blank input" do
      expect(helper.mark_script(nil)).to(eq(""))
      expect(helper.mark_script("")).to(eq(""))
    end
  end
end
