# frozen_string_literal: true

module Scans
  module Credentials
    FRESH = 10.minutes

    Saved = Data.define(:outcome, :hint) do
      def stored? = outcome == :ok
    end

    module_function

    def current = ScanCredential.current

    def check(key = current.api_key)
      return :missing if key.nil?

      outcome = KeyCheck.call(key)
      case outcome
      when :ok
        succeeded(key, fresh: 0.seconds)
      when :rejected
        rejected(key)
      end

      outcome
    end

    def save(text, expires_on: nil, now: Time.current)
      secret = ApiKey.normalize(text)
      return Saved.new(outcome: :malformed, hint: nil) unless ApiKey.plausible?(secret)
      return Saved.new(outcome: :no_encryption, hint: nil) unless ScanCredential.encryption_ready?

      key = ApiKey.new(secret, "stored")
      outcome = KeyCheck.call(key)
      return Saved.new(outcome:, hint: key.hint) unless outcome == :ok

      store(key, expires_on:, now:)
      Incidents.reopen(now)
      Saved.new(outcome: :ok, hint: key.hint)
    end

    def choose_model(name)
      chosen = name.presence
      return :unknown if chosen && !Pricing.known?(chosen)

      key = current.api_key
      return :missing if key.nil?

      outcome = KeyCheck.call(key, model: chosen || Settings.environment_model)
      case outcome
      when :ok
        succeeded(key, fresh: 0.seconds)
        ScanCredential.row!.update!(model: chosen)
      when :rejected
        rejected(key)
      end

      outcome
    end

    def forget
      ScanCredential.row!.update!(secret: nil, hint: nil, set_at: nil, expires_on: nil, expiry_warned_on: nil)
      check
    end

    def succeeded(key, fresh: FRESH, now: Time.current)
      return false unless in_use?(key)

      ScanCredential.row!
      ScanCredential
        .where(id: ScanCredential::ID)
        .where(
          "state <> 'ok' OR checked_digest IS DISTINCT FROM :digest OR checked_at IS NULL OR checked_at <= :stale",
          digest: key.digest,
          stale: now - fresh
        )
        .update_all(state: "ok", checked_digest: key.digest, checked_at: now, rejected_at: nil, updated_at: now) == 1
    rescue StandardError => error
      Rails.logger.error("scan key success was not recorded: #{error.class.name}")
      false
    end

    def rejected(key, now: Time.current)
      return false unless in_use?(key)

      ScanCredential.row!
      changed = ScanCredential
        .where(id: ScanCredential::ID)
        .where("state <> 'rejected' OR checked_digest IS DISTINCT FROM ?", key.digest)
        .update_all(
          [
            "state = 'rejected', rejected_at = :now, updated_at = :now, " \
              "checked_at = CASE WHEN checked_digest = :digest THEN checked_at END, checked_digest = :digest",
            {now:, digest: key.digest}
          ]
        ) == 1
      Alerts.notify("rejected", at: now) if changed
      changed
    end

    def watch(now: Time.current)
      credential = current
      outcome = check(credential.api_key) if credential.check_due?(now)
      warned = warn_expiry(current, now)
      {checked: outcome, expiry_warned: warned}
    end

    def warn_expiry(credential, now)
      days = credential.days_left(now.in_time_zone(Time.zone_default).to_date)
      return false if credential.stored_key.nil? || days.nil? || !days.between?(0, 1)

      claimed = ScanCredential
        .where(id: ScanCredential::ID, expires_on: credential.expires_on)
        .where("expiry_warned_on IS DISTINCT FROM expires_on")
        .update_all(expiry_warned_on: credential.expires_on, updated_at: now) == 1
      Alerts.notify("expiring", at: now) if claimed
      claimed
    end

    def store(key, expires_on:, now:)
      ScanCredential.row!.update!(
        secret: key.reveal,
        hint: key.hint,
        set_at: now,
        expires_on:,
        expiry_warned_on: nil,
        state: "ok",
        checked_digest: key.digest,
        checked_at: now,
        rejected_at: nil
      )
    end

    def in_use?(key) = key.is_a?(ApiKey) && key == current.api_key
  end
end
