# frozen_string_literal: true

class MailLinksController < ApplicationController
  include MailLanding

  before_action :set_link

  def show
    return inactive if @link.nil? || @link.kind == "unsubscribe"
    return visit if @link.kind == "visit"
    return land("session") if owner_signed_in?
    return render(:show) if @link.login_open?

    inactive("inactive")
  end

  def create
    return inactive if @link.nil? || @link.kind != "open"
    return land("session") if owner_signed_in?
    return inactive("inactive") unless @link.consume!

    terminate_session if authenticated?
    reset_session
    start_new_session_for(@link.user)
    land("login")
  end

  private

  def set_link
    @link = MailLink.find_by_token(params[:token])
    speak_to(@link&.user)
  end

  def owner_signed_in? = authenticated? && current_user.id == @link.user_id

  def land(source)
    @link.consume!
    @link.record_click!(source:)
    redirect_to(own_path?(@link.target) ? @link.target : desk_path(locale: @link.user.locale), allow_other_host: false)
  end

  def visit
    @link.record_click!(source: "visit")
    redirect_to(Newsletters::Tracking.visitable?(@link.target) ? @link.target : root_path, allow_other_host: true)
  end

  def inactive(source = nil)
    @link&.record_click!(source:) if source
    remember_return_path(@link.target) if @link && own_path?(@link.target)
    render(:inactive, status: :gone)
  end
end
