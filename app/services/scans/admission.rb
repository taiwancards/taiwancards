# frozen_string_literal: true

module Scans
  class Admission
    LOCK = 0x5ca9

    Result = Data.define(:scan, :refusal) do
      def admitted? = refusal.nil?
    end

    def self.client_digest(address)
      ip = IPAddr.new(address.to_s)
      ip = ip.mask(64) if ip.ipv6?
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("scan client"), ip.to_s).first(32)
    rescue IPAddr::InvalidAddressError
      nil
    end

    def initialize(user:, address:, upload:, now: Time.current)
      @user = user
      @digest = self.class.client_digest(address)
      @upload = upload
      @now = now
      @day = Scan.learner_day(user, at: now)
    end

    def call
      Scan.transaction do
        Scan.connection.execute("SELECT pg_advisory_xact_lock(#{LOCK})")
        Scan.reap_stale
        refusal = refusal_reason
        refusal ? Result.new(scan: nil, refusal:) : Result.new(scan: create_scan, refusal: nil)
      end
    end

    private

    def refusal_reason
      return "unavailable" unless Settings.usable?
      return "paused" if ScanPause.active.exists?
      return "quota" if Scan.used(@user, day: @day) >= Scan::DAILY
      return "quota" if Scan.where(user: @user, day: @day).count >= Scan::ATTEMPTS
      return "client" if @digest.nil? || from_client >= Settings.client_daily
      if Scan.where(created_at: @now.in_time_zone(Time.zone_default).all_day).count >= Settings.global_daily
        return trip_ceiling
      end

      return "busy" if Scan.in_flight.count >= Settings.concurrency

      nil
    end

    def trip_ceiling
      Incidents.pause("ceiling")
      "paused"
    end

    def from_client = Scan.where(client_digest: @digest, created_at: (@now - 24.hours)..).count

    def create_scan
      Scan.create!(
        user: @user,
        day: @day,
        client_digest: @digest,
        bytes: @upload.size,
        width: @upload.width,
        height: @upload.height,
        model: Settings.model
      )
    end
  end
end
