# frozen_string_literal: true

require "digest"

module Deploy
  class SyncGuard
    KEY = "sync_fingerprints"

    def initialize(name, paths)
      @name = name.to_s
      @paths = Array(paths).select(&:exist?)
    end

    def stale?
      return true if forced?

      stored != fingerprint
    end

    def remember!
      setting = Setting.instance
      prints = setting.data[KEY].is_a?(Hash) ? setting.data[KEY] : {}
      setting.update!(data: setting.data.merge(KEY => prints.merge(@name => fingerprint)))
    end

    def fingerprint
      @fingerprint ||= Digest::SHA256.hexdigest(@paths.map { |path| Digest::SHA256.file(path).hexdigest }.join)
    end

    private

    def forced?
      ActiveModel::Type::Boolean.new.cast(ENV["FORCE_SYNC"]).present?
    end

    def stored
      prints = Setting.instance.data[KEY]
      prints.is_a?(Hash) ? prints[@name] : nil
    end
  end
end
