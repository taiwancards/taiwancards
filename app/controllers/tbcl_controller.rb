# frozen_string_literal: true

class TbclController < ApplicationController
  include LevelLists
  allow_unauthenticated_access
  publicly_cacheable
  include Paginated
  include ProgressMarks

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
    page, = paginate(readiness.scope(@grade).curriculum_order, per_page: PER_PAGE, total: @stat.total)
    @lexemes = page.to_a
    load_progress(@lexemes)
  end
end
