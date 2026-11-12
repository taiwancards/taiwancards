# frozen_string_literal: true

module PubliclyCacheable
  extend ActiveSupport::Concern

  SHARED_TTL = ENV.fetch("PUBLIC_SHARED_TTL", 1.day.to_i).to_i
  STALE_TTL = ENV.fetch("PUBLIC_STALE_TTL", 7.days.to_i).to_i
  SHARED_VARY = "Accept-Encoding"
  ADDRESSED_FORMATS = %w[html csv json].freeze

  PERSONAL = [
    ZhuyinHelper::HANZI_FONT_COOKIE,
    ZhuyinHelper::READINGS_COOKIE,
    ZhuyinHelper::CHINA_COOKIE,
    DetailLevelHelper::DETAIL_COOKIE
  ].freeze

  included do
    class_attribute(:public_cache_actions, default: nil)
    class_attribute(:public_cache_ttl, default: SHARED_TTL)
    class_attribute(:public_cache_stale, default: STALE_TTL)

    prepend_before_action :answer_without_a_session
    after_action :allow_shared_caching

    helper_method :sessionless?
  end

  def cache_at_the_edge(ttl: SHARED_TTL, stale: STALE_TTL)
    expires_in(0, public: true, "s-maxage": ttl, "stale-while-revalidate": stale)
    response.headers["Vary"] = SHARED_VARY
  end

  class_methods do
    def publicly_cacheable(only: nil, ttl: SHARED_TTL, stale: STALE_TTL)
      self.public_cache_actions = only ? Array(only).map(&:to_s) : :all
      self.public_cache_ttl = ttl.to_i
      self.public_cache_stale = stale.to_i
    end
  end

  private

  def publicly_cacheable?
    actions = public_cache_actions
    return false if actions.nil?
    return false unless actions == :all || actions.include?(action_name)

    request.get? && !request.xhr? && !turbo_frame_request? && shareable_format? && current_user.nil? && plain_reader?
  end

  def shareable_format?
    addressed = params[:format].presence
    return ADDRESSED_FORMATS.include?(addressed.to_s) if addressed

    request.format.html? || request.format.to_s == Mime::ALL.to_s
  end

  def addressed_format?(format) = params[:format].to_s == format.to_s

  def plain_reader? = PERSONAL.none? { |name| cookies[name].present? }

  def sessionless? = request.session_options[:skip].present?

  def answer_without_a_session
    request.session_options[:skip] = true if publicly_cacheable?
  end

  def allow_shared_caching
    return unless sessionless?
    return unless response.status == 200

    cache_at_the_edge(ttl: public_cache_ttl, stale: public_cache_stale)
  end
end
