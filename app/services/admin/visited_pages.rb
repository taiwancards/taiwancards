# frozen_string_literal: true

module Admin
  class VisitedPages
    LABEL_LIMIT = 80
    READ = "GET"
    WEB = %r{\Ahttps?://}i
    UNRECOGNIZED = [ActionController::RoutingError, ArgumentError, URI::Error, EncodingError].freeze

    Page = Data.define(:path, :label, :href, :hidden) do
      def short_label = label&.truncate(LABEL_LIMIT)

      def title = [label, path].compact_blank.join(" — ")
    end

    Visit = Data.define(:address, :verb) do
      def self.of(address, verb = nil) = new(address: address.to_s, verb: verb.to_s.upcase.presence || READ)

      def site? = address.start_with?(PageView::SITE)

      def origin = parts.first

      def location = parts.last

      def parts = Locales.split_origin(address.delete_prefix(PageView::SITE))

      def relative? = origin.empty?
    end

    def initialize(addresses, labels: PageLabels.new)
      @visits = addresses.map { |address, verb| Visit.of(address, verb) }.uniq
      @labels = labels
    end

    def fetch(address, verb = nil)
      visit = Visit.of(address, verb)
      pages[visit] || build(visit, recognize(visit), {})
    end

    private

    def pages
      @pages ||= begin
        routes = @visits.index_with { |visit| recognize(visit) }
        found = @labels.call(routes.values)
        routes.to_h { |visit, route| [visit, build(visit, route, found)] }
      end
    end

    def build(visit, route, found)
      label = found[route] if route
      secrets = secrets_in(route)
      hidden = label&.hidden || false
      Page.new(
        path: shown_path(visit, secrets),
        label: label&.text,
        href: (href(visit) if secrets.empty? && !hidden),
        hidden:
      )
    end

    def shown_path(visit, secrets)
      readable = StoredPath.readable(visit.location)
      masked = secrets.reduce(readable) { |path, (value, mask)| path.sub(value, mask) }
      "#{PageView::SITE if visit.site?}#{masked}"
    end

    def href(visit)
      return nil unless visit.relative? || visit.origin.match?(WEB)
      return nil unless (visit.verb == READ ? recognize(visit) : recognize(visit, READ))

      visit.relative? ? visit.location : "#{visit.origin}#{visit.location}"
    end

    def recognize(visit, verb = visit.verb)
      path = visit.location
      return nil unless path.start_with?("/") && !path.start_with?("//")

      Rails.application.routes.recognize_path(path, method: verb)
    rescue *UNRECOGNIZED
      nil
    end

    def secrets_in(route)
      return [] if route.nil?

      filtered = parameter_filter.filter(route)
      route.filter_map do |name, value|
        next if filtered[name] == value || !value.is_a?(String)

        [StoredPath.text(value), filtered[name].to_s]
      end
    end

    def parameter_filter
      @parameter_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end
  end
end
