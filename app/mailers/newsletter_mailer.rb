# frozen_string_literal: true

class NewsletterMailer < ActionMailer::Base
  layout false

  def issue(delivery)
    newsletter = delivery.newsletter
    I18n.with_locale(delivery.locale) do
      unsubscribe = newsletter_unsubscribe_url(
        token: delivery.signed_id(purpose: :unsubscribe),
        locale: delivery.locale
      )
      headers["List-Unsubscribe"] = "<#{unsubscribe}>"
      headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
      compose(newsletter, delivery.user.email, link: -> (url) { tracked(delivery, url) }, unsubscribe:)
    end
  end

  def sample(newsletter, email, locale)
    I18n.with_locale(locale) do
      compose(
        newsletter,
        email,
        link: -> (url) { Newsletters::Tracking.absolute(url) },
        unsubscribe: settings_url,
        prefix: "[Test] "
      )
    end
  end

  private

  def compose(newsletter, email, link:, unsubscribe:, prefix: "")
    locale = I18n.locale.to_s
    image_src = attach_images(newsletter, locale)
    @letter = Newsletters::Letter.new(
      newsletter,
      locale:,
      image_src:,
      link:,
      unsubscribe_url: unsubscribe,
      settings_url:
    )

    mail(
      to: email,
      from: email_address_with_name(MailSettings.from_address, t("newsletters.mail.from_name")),
      reply_to: MailSettings.reply_to,
      subject: "#{prefix}#{@letter.subject}"
    ) do |format|
      format.text { render(plain: @letter.text) }
      format.html { render("newsletter_mailer/letter") }
    end
  end

  def attach_images(newsletter, locale)
    wanted = Newsletters::Body.image_ids(newsletter.body(locale))
    images = newsletter.images.where(id: wanted).index_by(&:id)
    images.each_value { |image|
      attachments.inline[image.filename] = {mime_type: image.content_type, content: image.data}
    }
    -> (id) { (image = images[id]) && attachments[image.filename].url }
  end

  def tracked(delivery, url)
    target = Newsletters::Tracking.absolute(url)
    return target unless Newsletters::Tracking.ours?(target)

    newsletter_click_url(token: Newsletters::Tracking.token(delivery, target), locale: nil)
  end

  def settings_url = profile_url(locale: I18n.locale)
end
