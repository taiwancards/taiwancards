# frozen_string_literal: true

module DeskStart
  def desk_start_path
    get("/desk")
    Nokogiri::HTML(response.body).at_css("[data-tour=\"learn\"]")&.[]("href")
  end
end

RSpec.configure do |config|
  config.include(DeskStart, type: :request)
end
