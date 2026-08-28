# frozen_string_literal: true

Rails.application.config.to_prepare do
  overlay = AppData.path("huayu/twfilter")
  TWFilter::Tables.overlay = overlay if File.directory?(overlay)
end
