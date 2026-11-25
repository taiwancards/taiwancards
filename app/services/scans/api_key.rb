# frozen_string_literal: true

module Scans
  class ApiKey
    PATTERN = /\Ask-ant-[A-Za-z0-9_-]{32,256}\z/
    SOURCES = %w[stored environment].freeze

    attr_reader :source

    def self.normalize(text) = text.to_s.gsub(/[[:space:]]+/, "")

    def self.plausible?(text) = PATTERN.match?(text.to_s)

    def initialize(secret, source)
      @secret = secret.to_s.dup.freeze
      @source = SOURCES.fetch(SOURCES.index(source.to_s))
    end

    def reveal = @secret

    def hint = @secret.last(4)

    def digest
      @digest ||= OpenSSL::HMAC
        .hexdigest(
          "SHA256",
          Rails.application.key_generator.generate_key("scan key digest"),
          @secret
        )
        .first(32)
    end

    def stored? = source == "stored"

    def ==(other) = other.is_a?(ApiKey) && other.digest == digest

    alias_method :eql?, :==

    def hash = digest.hash

    def inspect = "#<#{self.class.name} #{source} …#{hint}>"

    alias_method :to_s, :inspect

    def as_json(*) = {source:, hint:}

    def pretty_print(printer) = printer.text(inspect)

    def marshal_dump = raise TypeError, "#{self.class.name} cannot be serialized"
  end
end
