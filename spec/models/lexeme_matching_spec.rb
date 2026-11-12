# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexeme do
  describe ".matching" do
    let!(:school) do
      create(:lexeme, text: "學校", meanings: {"en" => "school", "ru" => "школа", "vi" => "trường học"})
    end

    let!(:teacher) {
      create(:lexeme, text: "老師", meanings: {"en" => "teacher", "ru" => "учитель", "vi" => "giáo viên"})
    }
    let!(:discount) { create(:lexeme, text: "打折", meanings: {"en" => "50% off"}) }

    it "finds an entry by its own text" do
      expect(described_class.matching("學")).to(contain_exactly(school))
    end

    it "finds an entry by its meaning in every interface language" do
      expect(described_class.matching("schoo")).to(contain_exactly(school))
      expect(described_class.matching("ШКОЛ")).to(contain_exactly(school))
      expect(described_class.matching("giáo")).to(contain_exactly(teacher))
    end

    it "reads a percent sign literally instead of as a wildcard" do
      expect(described_class.matching("%")).to(contain_exactly(discount))
    end

    it "reads an underscore literally instead of as a wildcard" do
      expect(described_class.matching("_")).to(be_empty)
    end
  end
end
