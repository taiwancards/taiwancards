# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexeme, "ordering scopes" do
  def word(text, data)
    create(:lexeme, kind: :word, text:, data:)
  end

  describe ".curriculum_order" do
    it "orders by TOCFL level first, then frequency within a level" do
      b1 = word("乙", {"tocfl_level" => "A1", "freq_rank" => 5})
      a1 = word("甲", {"tocfl_level" => "Novice1", "freq_rank" => 900})
      a2 = word("丙", {"tocfl_level" => "Novice1", "freq_rank" => 30})

      ordered = Lexeme.where(kind: :word).curriculum_order.pluck(:text)

      expect(ordered).to(eq([a2.text, a1.text, b1.text]))
    end

    it "falls back to TBCL grade when TOCFL level is absent, nulls last" do
      graded = word("級", {"tbcl_grade" => 1, "freq_rank" => 100})
      leveled = word("平", {"tocfl_level" => "Novice2", "freq_rank" => 100})
      bare = word("無", {"freq_rank" => 1})

      ordered = Lexeme.where(kind: :word).curriculum_order.pluck(:text)

      expect(ordered).to(eq([graded.text, leveled.text, bare.text]))
    end
  end

  describe ".frequency_order" do
    it "orders purely by frequency rank regardless of level" do
      high = word("高", {"tocfl_level" => "C", "freq_rank" => 2})
      low = word("低", {"tocfl_level" => "Novice1", "freq_rank" => 50})

      ordered = Lexeme.where(kind: :word).frequency_order.pluck(:text)

      expect(ordered).to(eq([high.text, low.text]))
    end
  end
end
