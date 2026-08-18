# frozen_string_literal: true

class SitemapsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :redirect_to_localised_url, raise: false

  def index
    render_xml(sitemap.index_xml)
  end

  def show
    name = params[:name].to_s
    return head(:not_found) unless sitemap.names.include?(name)

    xml = sitemap.urlset_xml(name)
    return head(:not_found) if xml.blank?

    render_xml(xml)
  end

  private

  def sitemap = @sitemap ||= Site::Sitemap.new(origin: request.base_url)

  def render_xml(body)
    cache_at_the_edge
    render(xml: body)
  end
end
