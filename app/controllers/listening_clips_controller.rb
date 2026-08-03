# frozen_string_literal: true

class ListeningClipsController < ApplicationController
  allow_unauthenticated_access

  CLIP_ID = /\A[a-zA-Z0-9_-]+\z/

  def show
    id = params[:id].to_s
    return head(:not_found) unless CLIP_ID.match?(id)

    root = AppData.media_path("listening/audio").cleanpath
    path = root.join("#{id}.mp3").cleanpath
    return head(:not_found) unless path.to_s.start_with?("#{root}/") && path.exist?

    expires_in(30.days, public: true)
    send_file(path.to_s, type: "audio/mpeg", disposition: "inline")
  end
end
