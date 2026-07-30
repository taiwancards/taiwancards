# frozen_string_literal: true

module Huayu
  class TbclReadiness
    GRADES = (1..7).to_a.freeze

    Stat = Data.define(:grade, :total, :started, :known) do
      def readiness
        total.zero? ? 0 : (known * 100.0 / total).round
      end
    end

    def levels
      totals = grouped(base)
      owned = LexemeMemory.owned_by(Current.user)
      started = grouped(base.where(id: owned.active.select(:lexeme_id)))
      known = grouped(base.where(id: owned.state_review.select(:lexeme_id)))

      GRADES.map do |grade|
        Stat.new(grade:, total: totals[grade].to_i, started: started[grade].to_i, known: known[grade].to_i)
      end
    end

    def stat(grade)
      levels.find { |level| level.grade == grade.to_i }
    end

    def scope(grade)
      base.where(tbcl_grade: grade.to_i)
    end

    private

    def base
      Lexeme.where(kind: Lexeme::DICTIONARY_KINDS).visible
    end

    def grouped(relation)
      relation.group(:tbcl_grade).count
    end
  end
end
