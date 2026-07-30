# frozen_string_literal: true

module Pagination
  Window = Data.define(:page, :pages, :per_page, :total) do
    def offset = (page - 1) * per_page

    def first? = page <= 1

    def last? = page >= pages

    def many? = pages > 1
  end

  module_function

  def for(total:, per_page:, page: 1)
    per_page = [per_page.to_i, 1].max
    total = [total.to_i, 0].max
    pages = [(total / per_page.to_f).ceil, 1].max
    Window.new(page: [page.to_i, 1].max.clamp(1, pages), pages: pages, per_page: per_page, total: total)
  end
end
