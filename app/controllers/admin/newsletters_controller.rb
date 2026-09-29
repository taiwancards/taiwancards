# frozen_string_literal: true

module Admin
  class NewslettersController < ApplicationController
    before_action :require_admin
    before_action :set_newsletter, except: %i[index create]
    before_action :require_draft, only: %i[update destroy]

    FIELDS = Newsletter::LOCALES.flat_map { |locale| %W[subject_#{locale} preheader_#{locale} body_#{locale}] }.freeze

    def index
      @newsletters = Newsletter.recent.to_a
      @stats = Newsletters::Stats.new(@newsletters)
      @unsubscribed = User.where.not(newsletter_unsubscribed_at: nil).order(newsletter_unsubscribed_at: :desc).to_a
      @recipients = Newsletter.recipients.group(:locale).count
    end

    def create
      redirect_to(edit_admin_newsletter_path(Newsletter.create!))
    end

    def edit
      @locale = params[:lang].presence_in(Newsletter::LOCALES) || Newsletter::LOCALES.last
      @recipients = Newsletter.recipients.group(:locale).count
      @deliveries = @newsletter.deliveries.includes(:user).order(:id).to_a if @newsletter.sent?
      @stats = Newsletters::Stats.new([@newsletter]).for(@newsletter)
      @budget = Newsletters::Dispatch.budget
      @preview = preview_html(@locale)
    end

    def update
      @newsletter.update!(newsletter_params)
      respond_to do |format|
        format.json { render(json: {html: preview_html(params[:lang].presence_in(Newsletter::LOCALES) || "en")}) }
        format.html {
          redirect_to(
            edit_admin_newsletter_path(@newsletter, lang: params[:lang]),
            notice: t("newsletters.admin.saved")
          )
        }
      end
    end

    def destroy
      @newsletter.destroy!
      redirect_to(admin_newsletters_path, notice: t("newsletters.admin.deleted"))
    end

    def sample
      locale = params[:lang].presence_in(Newsletter::LOCALES) || "en"
      NewsletterMailer.sample(@newsletter, current_user.email, locale).deliver_now
      redirect_to(
        edit_admin_newsletter_path(@newsletter, lang: locale),
        notice: t("newsletters.admin.sample_sent", email: current_user.email)
      )
    rescue StandardError => error
      redirect_to(
        edit_admin_newsletter_path(@newsletter, lang: locale),
        alert: t("newsletters.admin.failed", error: error.message.first(200))
      )
    end

    def deliver
      unless @newsletter.complete?
        return redirect_to(edit_admin_newsletter_path(@newsletter), alert: t("newsletters.admin.incomplete"))
      end

      unless MailSettings.ready?
        return redirect_to(edit_admin_newsletter_path(@newsletter), alert: t("newsletters.admin.not_configured"))
      end

      Newsletters::Dispatch.new(@newsletter).call
      redirect_to(edit_admin_newsletter_path(@newsletter), notice: t("newsletters.admin.dispatched"))
    end

    private

    def set_newsletter
      @newsletter = Newsletter.find(params[:id])
    end

    def require_draft
      redirect_to(edit_admin_newsletter_path(@newsletter), alert: t("newsletters.admin.locked")) if @newsletter.sent?
    end

    def newsletter_params
      permitted = params.expect(newsletter: [*FIELDS, buttons: [%i[label_en label_ru url]]])
      buttons = permitted[:buttons]
      permitted[:buttons] = (buttons.respond_to?(:values) ? buttons.values : buttons).map(&:to_h) if buttons
      permitted
    end

    def preview_html(locale)
      I18n.with_locale(locale) do
        @letter = Newsletters::Letter.new(
          @newsletter,
          locale:,
          image_src: -> (id) { newsletter_image_path(id, locale: nil) },
          link: -> (url) { Newsletters::Tracking.absolute(url) },
          unsubscribe_url: "#",
          settings_url: profile_url(locale:)
        )
        String.new(render_to_string(template: "newsletter_mailer/letter", layout: false, formats: [:html]))
      end
    end
  end
end
