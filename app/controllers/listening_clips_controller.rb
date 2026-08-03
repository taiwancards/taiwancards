# frozen_string_literal: true

class ListeningClipsController < ApplicationController
  allow_unauthenticated_access

  CLIP_ID = /\A[\w.-]+\z/

  def show
    id = params[:id].to_s
    return head(:not_found) unless CLIP_ID.match?(id)

    path = AppData.media_path("listening/audio/#{id}.mp3")
    return head(:not_found) unless path.exist?

    expires_in(30.days, public: true)
    send_file(path, type: "audio/mpeg", disposition: "inline")
  end
end
