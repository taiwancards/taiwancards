# frozen_string_literal: true

module AndroidApp
  RELATION = "delegate_permission/common.handle_all_urls"
  PACKAGE = /\A[a-zA-Z][a-zA-Z0-9_]*(?:\.[a-zA-Z][a-zA-Z0-9_]*)+\z/
  DIGEST = /\A[0-9A-F]{64}\z/

  module_function

  def package = ENV["ANDROID_PACKAGE_NAME"].to_s.strip

  def fingerprints = ENV["ANDROID_CERT_FINGERPRINTS"].to_s.split(",").map(&:strip).reject(&:empty?)

  def configured?
    package.match?(PACKAGE) && fingerprints.any? && fingerprints.all? { |value| digest(value).match?(DIGEST) }
  end

  def asset_links
    [
      {
        relation: [RELATION],
        target: {
          namespace: "android_app",
          package_name: package,
          sha256_cert_fingerprints: fingerprints.map { |value| digest(value).scan(/../).join(":") }.uniq
        }
      }
    ]
  end

  def digest(value) = value.delete(":").upcase
end
