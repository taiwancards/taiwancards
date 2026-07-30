# frozen_string_literal: true

class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[licenses privacy_policy terms_of_service]
  before_action :send_to_the_site, only: %i[licenses privacy_policy terms_of_service]

  def help
  end

  def licenses
  end

  def privacy_policy
  end

  def terms_of_service
  end

  def menu
  end

  private

  def send_to_the_site
    return unless Site.published?

    redirect_to(Site.page_url(request.path), allow_other_host: true, status: :moved_permanently)
  end
end
