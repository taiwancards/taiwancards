# frozen_string_literal: true

require "rails_helper"

RSpec.describe PracticeHelper do
  describe "#phon_cell" do
    let(:row) {
      {"pinyin" => "ü written as u", "pinyin_i18n" => {"de" => "ü, als u geschrieben"}, "written" => "ju, qu"}
    }

    it "shows the label written for the reader's language" do
      I18n.with_locale(:de) { expect(helper.phon_cell(row, "pinyin")).to(eq("ü, als u geschrieben")) }
    end

    it "keeps the base label for a language without its own" do
      I18n.with_locale(:en) { expect(helper.phon_cell(row, "pinyin")).to(eq("ü written as u")) }
    end

    it "keeps a cell that has no translations at all" do
      I18n.with_locale(:de) { expect(helper.phon_cell(row, "written")).to(eq("ju, qu")) }
    end
  end
end
