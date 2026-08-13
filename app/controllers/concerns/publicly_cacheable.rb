# frozen_string_literal: true

module PubliclyCacheable
  extend ActiveSupport::Concern

  SHARED_TTL = 10.minutes
  STALE_TTL = 1.day

  PERSONAL = [
    ZhuyinHelper::HANZI_FONT_COOKIE,
    ZhuyinHelper::PINYIN_COOKIE,
    ZhuyinHelper::CHINA_COOKIE,
    DetailLevelHelper::DETAIL_COOKIE
  ].freeze

  included do
    class_attribute(:public_cache_actions, default: nil)

    prepend_before_action :answer_without_a_session
    after_action :allow_shared_caching

    helper_method :sessionless?
  end

  class_methods do
    def publicly_cacheable(only: nil)
      self.public_cache_actions = only ? Array(only).map(&:to_s) : :all
    end
  end

  private

  def publicly_cacheable?
    actions = public_cache_actions
    return false if actions.nil?
    return false unless actions == :all || actions.include?(action_name)

    request.get? && !request.xhr? && html_answer? && current_user.nil? && plain_reader?
  end

  def html_answer? = request.format.html? || request.format.to_s == Mime::ALL.to_s

  def plain_reader? = PERSONAL.none? { |name| cookies[name].present? }

  def sessionless? = request.session_options[:skip].present?

  def answer_without_a_session
    request.session_options[:skip] = true if publicly_cacheable?
  end

  def allow_shared_caching
    return unless sessionless?
    return unless response.status == 200

    expires_in(0, public: true, "s-maxage": SHARED_TTL.to_i, "stale-while-revalidate": STALE_TTL.to_i)
  end
end
