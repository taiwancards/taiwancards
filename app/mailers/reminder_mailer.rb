# frozen_string_literal: true

class ReminderMailer < ActionMailer::Base
  include MailLinking

  layout "reminder_mailer"

  def nudge(delivery)
    @delivery = delivery
    letter = Reminders::Letter.new(delivery)
    link_mail_to(user: delivery.user, list: "reminders", letter: delivery.trigger, delivery:)
    I18n.with_locale(delivery.locale) do
      @key = letter.key
      @vars = letter.vars
      @click_url = open_url(delivery.path)
      @schedule_url = open_url(profile_url(locale: I18n.locale, anchor: "reminders", only_path: true))
      @settings_url = open_url(profile_url(locale: I18n.locale, anchor: "mail", only_path: true))
      @off_url = unsubscribe_all_url
      @subject = letter.subject
      headers["List-Unsubscribe"] = "<#{@off_url}>"
      headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

      mail(
        to: delivery.user.email,
        from: email_address_with_name(MailSettings.from_address, t("newsletters.mail.from_name")),
        reply_to: MailSettings.reply_to,
        subject: @subject,
        template_name: letter.welcome? ? "welcome" : "nudge"
      )
    end
  end
end
