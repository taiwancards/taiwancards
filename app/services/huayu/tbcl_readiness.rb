# frozen_string_literal: true

module Huayu
  class TbclReadiness
    GRADES = (1..7).to_a.freeze

    Stat = Data.define(:grade, :total, :started, :known) do
      def readiness
        total.zero? ? 0 : (known * 100.0 / total).round
      end
    end

    PROGRESS = [
      "lexemes.tbcl_grade",
      "count(DISTINCT lexemes.id) FILTER (WHERE lexeme_memories.activated_at IS NOT NULL)",
      "count(DISTINCT lexemes.id) FILTER (WHERE lexeme_memories.state = #{LexemeMemory.states.fetch("review")})"
    ]
      .map { |column| Arel.sql(column) }
      .freeze

    def initialize(user:)
      @user = user
    end

    def levels
      @levels ||= begin
        counted = progress
        GRADES.map do |grade|
          started, known = counted[grade]
          Stat.new(grade:, total: totals[grade].to_i, started: started.to_i, known: known.to_i)
        end
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
      Lexeme.where(kind: Lexeme::DICTIONARY_KINDS).visible_to(@user)
    end

    def totals
      @totals ||= ContentCache.fetch("tbcl/totals", Lexeme.visibility_key(@user)) do
        base.where.not(tbcl_grade: nil).group(:tbcl_grade).count
      end
    end

    def progress
      return {} if @user.nil?

      base
        .where
        .not(tbcl_grade: nil)
        .joins(:memories)
        .merge(LexemeMemory.owned_by(@user))
        .group(:tbcl_grade)
        .pluck(*PROGRESS)
        .to_h { |grade, started, known| [grade, [started, known]] }
    end
  end
end
