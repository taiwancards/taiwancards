# frozen_string_literal: true

class TocflController < ApplicationController
  include LevelLists
  allow_unauthenticated_access
  publicly_cacheable
  include Paginated
  include ProgressMarks

  PER_PAGE = 600

  def index
    @levels = Huayu::TocflReadiness.new.levels
  end

  def show
    @collection = Collection.tocfl.find(params[:id])
    return send_level_list(@collection.lexemes.curriculum_order, @collection.name) if request.format.csv?

    @stat = Huayu::TocflReadiness.new.stat(@collection)
    page, = paginate(
      @collection.lexemes.order(Arel.sql("collection_items.position")),
      per_page: PER_PAGE,
      total: @stat.total
    )
    @lexemes = page.to_a
    load_progress(@lexemes)
  end
end
