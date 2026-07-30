# frozen_string_literal: true

class MoeClipsController < ApplicationController
  def notice
    path = Huayu::MoeAudio.notice_path
    return head(:not_found) if path.nil?

    expires_in(30.days, public: true)
    send_file(path, type: "application/pdf", disposition: "inline", filename: "moe-usage-notice.pdf")
  end

  def show
    path = Huayu::MoeAudio.clip_path(params[:scope].to_s, params[:id].to_s)
    return head(:not_found) if path.nil?

    expires_in(30.days, public: true)
    send_file(path, type: "audio/ogg", disposition: "inline")
  end
end
