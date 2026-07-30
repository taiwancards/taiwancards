# frozen_string_literal: true

class DetailPrefsController < ApplicationController
  def update
    mode = params[:mode].to_s.presence_in(DetailLevelHelper::DETAIL_MODES)
    return redirect_back(fallback_location: dict_path) if mode.nil?

    cookies.permanent[DetailLevelHelper::DETAIL_COOKIE] = {value: mode, same_site: :lax}
    redirect_back(fallback_location: dict_path)
  end
end
