# frozen_string_literal: true

module Newsletters
  module Body
    TAGS = %w[div p br strong b em i u del a ul ol li h1 h2 blockquote pre figure figcaption img].freeze
    ATTRIBUTES = %w[href src alt width height].freeze
    SANITIZER = Rails::HTML5::SafeListSanitizer.new
    IMAGE = %r{/newsletter_images/(\d+)}

    module_function

    def clean(html) = SANITIZER.sanitize(settle_attachments(html.to_s), tags: TAGS, attributes: ATTRIBUTES).strip

    def settle_attachments(html)
      return html unless html.include?("<figure") || html.include?("newsletter_images")

      require "nokolexbor"

      body = Nokolexbor::HTML(html).at_css("body")
      body.css("figcaption.attachment__caption:not(.attachment__caption--edited)").each(&:remove)
      body.css("a").select { |link| link["href"].to_s.match?(IMAGE) }.each { |link| link.replace(link.children) }
      body.inner_html
    end

    def image_ids(html) = html.to_s.scan(IMAGE).flatten.map(&:to_i).uniq
  end
end
