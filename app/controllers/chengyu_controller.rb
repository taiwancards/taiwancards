# frozen_string_literal: true

class ChengyuController < ApplicationController
  allow_unauthenticated_access
  include Paginated
  include ProgressMarks

  PER_PAGE = 60
  BANDS = %w[easy medium hard].freeze

  def index
    @tone = params[:tone].presence_in(Huayu::ChengyuImporter::TONES)
    @kind = params[:kind].presence_in(Huayu::ChengyuImporter::KINDS)
    @grade = params[:grade].presence_in(%w[1 2 3 4 5 6 7 advanced])
    @band = params[:band].presence_in(BANDS)
    @q = params[:q].to_s.strip

    @counts = facets
    content_key = ["chengyu", @tone, @kind, @grade, @band, @q].join("|")
    page, = paginate(filtered(base).curriculum_order, per_page: PER_PAGE, content_key: content_key)
    @entries = page.to_a
    load_progress(@entries)
  end

  private

  def base
    Lexeme
      .where(kind: Lexeme::DICTIONARY_KINDS)
      .visible
      .where("lexemes.data ->> 'chengyu' = 'true'")
  end

  def filtered(scope)
    scope = scope.where("lexemes.data ->> 'chengyu_tone' = ?", @tone) if @tone
    scope = scope.where("lexemes.data ->> 'chengyu_kind' = ?", @kind) if @kind
    scope = apply_grade(scope) if @grade
    scope = apply_band(scope) if @band
    return scope if @q.blank?

    scope.where(
      "lexemes.text ILIKE :q OR lexemes.meanings ->> 'en' ILIKE :q OR lexemes.meanings ->> 'ru' ILIKE :q",
      q: "%#{@q}%"
    )
  end

  def apply_grade(scope)
    return scope.where("lexemes.data ->> 'tbcl_grade' IS NULL") if @grade == "advanced"

    scope.where("lexemes.data ->> 'tbcl_grade' = ?", @grade)
  end

  def apply_band(scope)
    low, high = band_edges
    case @band
    when "easy"
      scope.where(score: ..low)
    when "medium"
      scope.where(score: low..high)
    else
      scope.where(score: high..)
    end
  end

  def band_edges
    @band_edges ||= Rails.cache.fetch("chengyu/band_edges/#{base.maximum(:updated_at).to_i}", expires_in: 1.day) do
      row = base.pick(
        Arel.sql(
          "percentile_cont(0.33) WITHIN GROUP (ORDER BY lexemes.score), " \
            "percentile_cont(0.66) WITHIN GROUP (ORDER BY lexemes.score)"
        )
      )
      Array(row).map { |value| value || 0.0 }
    end
  end

  def facets
    ContentCache.fetch("chengyu/facets", Lexeme.visibility_key) do
      {
        tone: base.group(Arel.sql("lexemes.data ->> 'chengyu_tone'")).count,
        kind: base.group(Arel.sql("lexemes.data ->> 'chengyu_kind'")).count,
        grade: base.group(Arel.sql("COALESCE(lexemes.data ->> 'tbcl_grade', 'advanced')")).count
      }
    end
  end
end
