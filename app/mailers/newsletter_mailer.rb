# frozen_string_literal: true

class NewsletterMailer < ActionMailer::Base
  include MailLinking

  layout false

  def issue(delivery, prefix: "")
    newsletter = delivery.newsletter
    link_mail_to(user: delivery.user, list: "newsletter", letter: newsletter.subject(delivery.locale), delivery:)
    I18n.with_locale(delivery.locale) do
      unsubscribe = unsubscribe_all_url
      headers["List-Unsubscribe"] = "<#{unsubscribe}>"
      headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
      compose(newsletter, delivery.user.email, link: -> (url) { tracked(url) }, unsubscribe:, prefix:)
    end
  end

  def sample(delivery) = issue(delivery, prefix: "[Test] ")

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

  def tracked(url)
    target = Newsletters::Tracking.absolute(url)
    return open_url(Newsletters::Tracking.path_of(target)) if Newsletters::Tracking.ours?(target)
    return visit_url(target) if Newsletters::Tracking.visitable?(target)

    target
  end

  def settings_url = open_url(profile_url(locale: I18n.locale, anchor: "mail", only_path: true))
end
