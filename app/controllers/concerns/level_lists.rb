# frozen_string_literal: true

module LevelLists
  extend ActiveSupport::Concern

  def send_level_list(scope, title)
    export = Lexemes::LevelExport.new(scope.visible, title:, origin: request.base_url)
    cache_at_the_edge
    send_data(
      export.to_csv,
      type: "text/csv; charset=utf-8",
      disposition: "attachment",
      filename: "#{title.parameterize}.csv"
    )
  end
end
