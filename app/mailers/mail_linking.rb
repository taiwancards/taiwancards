# frozen_string_literal: true

module MailLinking
  private

  def link_mail_to(user:, list:, letter:, delivery:)
    @mail_link_scope = {user:, list:, letter:, delivery:}
    @unsubscribe_all_url = nil
  end

  def open_url(path) = mail_link_url(token: issue_link("open", path), locale: nil)

  def visit_url(url) = mail_link_url(token: issue_link("visit", url), locale: nil)

  def unsubscribe_all_url
    @unsubscribe_all_url ||= mail_unsubscribe_url(token: issue_link("unsubscribe", ""), locale: nil)
  end

  def issue_link(kind, target) = MailLink.issue(kind:, target:, **@mail_link_scope).token
end
