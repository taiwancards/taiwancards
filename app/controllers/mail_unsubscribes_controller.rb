# frozen_string_literal: true

class MailUnsubscribesController < ApplicationController
  include MailLanding

  skip_forgery_protection only: :create

  before_action :set_link

  def show
    render(status: @link ? :ok : :not_found)
  end

  def create
    return render(:show, status: :not_found) if @link.nil?

    user = @link.user
    now = Time.current
    user.mailing_source = MailEvent.source_for(params)
    user.update!(reminders: false, newsletter: false)
    if @link.delivery.is_a?(NewsletterDelivery)
      @link.delivery.update_columns(unsubscribed_at: @link.delivery.unsubscribed_at || now)
    end

    render(:done)
  end

  private

  def set_link
    link = MailLink.find_by_token(params[:token])
    @link = link if link&.kind == "unsubscribe"
    speak_to(@link&.user)
  end
end
