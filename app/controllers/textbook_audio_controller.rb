# frozen_string_literal: true

class TextbookAudioController < ApplicationController
  allow_unauthenticated_access
  before_action :require_restricted_access_silently

  def show
    kind, source = TextbookLesson.audio_source(params[:name])
    return head(:not_found) if kind.nil?

    kind == :file ? serve(source) : redirect_to(source, allow_other_host: true, status: :found)
  end

  private

  def serve(path)
    expires_in(7.days, public: false, must_revalidate: true)
    response.etag = [path.basename.to_s, path.size, path.mtime.to_i]
    response.last_modified = path.mtime
    return head(:not_modified) if request.fresh?(response)

    send_file(path, type: "audio/mpeg", disposition: "inline")
  end

  def require_restricted_access_silently
    head(:not_found) unless current_user&.restricted_access?
  end
end
