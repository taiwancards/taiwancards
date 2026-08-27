# frozen_string_literal: true

class TbclController < ApplicationController
  include LevelLists
  allow_unauthenticated_access
  publicly_cacheable
  include Paginated
  include ProgressMarks
  include MarkedEntries

  PER_PAGE = 600

  def index
    @levels = Huayu::TbclReadiness.new.levels
  end

  def show
    @grade = params[:id].to_i
    raise ActiveRecord::RecordNotFound unless Huayu::TbclReadiness::GRADES.include?(@grade)

    readiness = Huayu::TbclReadiness.new
    return send_level_list(readiness.scope(@grade).curriculum_order, "TBCL #{@grade}") if request.format.csv?

    @stat = readiness.stat(@grade)
    ordered = readiness.scope(@grade).curriculum_order
    page, = paginate(ordered, per_page: PER_PAGE, total: @stat.total)
    @marked = marked_entries(ordered)
    @lexemes = page.to_a
    load_progress(@lexemes + @marked)
  end
end
