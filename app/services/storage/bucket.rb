# frozen_string_literal: true

require "aws-sdk-s3"

module Storage
  class Bucket
    Missing = Class.new(StandardError)

    LINK_TTL = 15.minutes
    PAGE = 1_000

    class << self
      def runtime = for_name(ENV.fetch("R2_RUNTIME_BUCKET", nil))

      def configured? = credentials.values.all?(&:present?)

      def reset! = @clients = nil

      def for_name(name)
        raise Missing, "no bucket name given" if name.blank?

        (@clients ||= {})[name] ||= new(name)
      end

      def credentials
        {
          endpoint: ENV.fetch("R2_ENDPOINT", nil),
          access_key_id: ENV.fetch("R2_ACCESS_KEY_ID", nil),
          secret_access_key: ENV.fetch("R2_SECRET_ACCESS_KEY", nil)
        }
      end
    end

    def initialize(name)
      @name = name
    end

    attr_reader :name

    def link(key, expires_in: LINK_TTL)
      signer.presigned_url(:get_object, bucket: @name, key: key, expires_in: expires_in.to_i)
    end

    def read(key)
      client.get_object(bucket: @name, key: key).body.read
    rescue Aws::S3::Errors::NoSuchKey
      nil
    end

    def exist?(key)
      client.head_object(bucket: @name, key: key)
      true
    rescue Aws::S3::Errors::NotFound
      false
    end

    def each_object(prefix)
      token = nil
      loop do
        page = client.list_objects_v2(bucket: @name, prefix: prefix, max_keys: PAGE, continuation_token: token)
        page.contents.each { |object| yield(object.key, object.size) }
        token = page.next_continuation_token
        break if token.nil?
      end
    end

    def download(key, path)
      path.dirname.mkpath
      client.get_object(bucket: @name, key: key, response_target: path.to_s)
      path
    end

    private

    def client
      @client ||= Aws::S3::Client.new(**options)
    end

    def signer
      @signer ||= Aws::S3::Presigner.new(client: client)
    end

    def options
      credentials = self.class.credentials
      raise Missing, "R2 credentials are not set" unless self.class.configured?

      {
        access_key_id: credentials[:access_key_id],
        secret_access_key: credentials[:secret_access_key],
        endpoint: credentials[:endpoint],
        region: "auto",
        force_path_style: true
      }
    end
  end
end
