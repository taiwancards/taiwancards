# frozen_string_literal: true

Rake::Task["assets:precompile"].enhance do
  written = PrecompressedAssets.write(Rails.application.config.assets.output_path)
  puts("assets: #{written} brotli copies written")
end
