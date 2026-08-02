# frozen_string_literal: true

class CnsClipsController < ApplicationController
  allow_unauthenticated_access
  def show
    path = Huayu::CnsVoice.clip_path(params[:voice].to_s, params[:key].to_s)
    return head(:not_found) if path.nil?

    expires_in(30.days, public: true)
    send_file(path, type: "audio/mpeg", disposition: "inline")
  end
end
