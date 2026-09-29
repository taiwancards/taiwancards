# frozen_string_literal: true

module Admin
  class NewsletterImagesController < ApplicationController
    before_action :require_admin

    def create
      newsletter = Newsletter.find(params[:newsletter_id])
      upload = params[:file]
      unless upload.respond_to?(:read) && upload.size <= NewsletterImage::MAX_BYTES && !newsletter.sent?
        return head(:unprocessable_entity)
      end

      image = NewsletterImage.from_upload(newsletter, upload)
      return head(:unprocessable_entity) unless image.save

      render(json: {url: newsletter_image_path(image, locale: nil), id: image.id})
    end

    def show
      image = NewsletterImage.find(params[:id])
      expires_in(1.hour, public: false)
      send_data(image.data, type: image.content_type, disposition: "inline", filename: image.filename)
    end
  end
end
