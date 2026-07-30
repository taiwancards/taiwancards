# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Compiled assets" do
  let(:builds) { Rails.root.join("app/assets/builds") }

  it "keeps the build directory on disk, so a fresh clone precompiles into it" do
    expect(builds).to(be_directory)
  end

  it "has that directory on the asset load path Propshaft reads at boot" do
    paths = Rails.application.config.assets.paths.map(&:to_s)

    expect(paths).to(include(builds.to_s))
  end
end
