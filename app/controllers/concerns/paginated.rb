# frozen_string_literal: true

module Paginated
  extend ActiveSupport::Concern

  private

  def paginate(scope, per_page:, total: nil, content_key: nil, page: nil)
    total ||= counted(scope, content_key)
    window = Pagination.for(total: total, per_page: per_page, page: page || params[:page])

    @page = window.page
    @pages = window.pages
    @total = window.total

    [scope.offset(window.offset).limit(window.per_page), window]
  end

  def counted(scope, content_key)
    return count_rows(scope) if content_key.nil?

    ContentCache.fetch("count", content_key, Lexeme.visibility_key) { count_rows(scope) }
  end

  def count_rows(scope)
    scope.except(:order, :limit, :offset).count(:all)
  end
end
