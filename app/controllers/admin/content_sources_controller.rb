# frozen_string_literal: true

module Admin
  class ContentSourcesController < ApplicationController
    before_action :require_admin

    def index
      @sources = ContentSource.ordered
    end

    def update
      source = ContentSource.find(params[:id])
      changed = source.update(source_params) && source.saved_changes?
      Render::Cloudflare.new.purge_everything if changed
      redirect_to(admin_content_sources_path, notice: t("admin.sources.saved", name: source.name))
    end

    private

    def source_params = params.expect(content_source: %i[enabled enabled_for_admins])
  end
end
