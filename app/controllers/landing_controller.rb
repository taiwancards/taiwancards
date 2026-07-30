# frozen_string_literal: true

class LandingController < ApplicationController
  allow_unauthenticated_access

  def show
    if Site.published?
      return redirect_to(desk_path) if authenticated?

      return redirect_to(Site.url, allow_other_host: true)
    end

    @counts = Site::Counts.fetch
  end
end
