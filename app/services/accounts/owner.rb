# frozen_string_literal: true

module Accounts
  class Owner
    Result = Data.define(:status, :id, :unlinked, :demoted) do
      def changed? = status != :kept && status != :unconfigured || unlinked.positive? || demoted.positive?

      def to_s
        return "owner unconfigured: ADMIN_GOOGLE_EMAIL is unset, no administrator exists" if status == :unconfigured

        "owner #{status}: ##{id}, google links released #{unlinked}, admin taken from #{demoted}"
      end
    end

    def call
      return Result.new(status: :unconfigured, id: nil, unlinked: 0, demoted: 0) if User.owner_google_email.nil?

      keeper = locate
      unlinked = release(keeper)
      status = keeper.new_record? ? :created : :kept
      assign(keeper)
      status = :repaired if status == :kept && keeper.changed?
      keeper.save!
      demoted = User.where(admin: true).where.not(id: keeper.id).update_all(admin: false)

      Result.new(status:, id: keeper.id, unlinked:, demoted:)
    end

    private

    def locate
      by_email = User.owner_email && User.find_by(email: User.owner_email)
      by_email || User.find_by(google_email: User.owner_google_email) || build
    end

    def build
      User.new(
        email: User.owner_email || User.owner_google_email,
        name: ENV.fetch("ADMIN_NAME", "Admin"),
        password: SecureRandom.base58(24)
      )
    end

    def release(keeper)
      scope = User.where(google_email: User.owner_google_email)
      scope = scope.where.not(id: keeper.id) if keeper.persisted?
      scope.update_all(google_email: nil, google_uid: nil, admin: false)
    end

    def assign(keeper)
      keeper.email = User.owner_email if User.owner_email
      keeper.google_email = User.owner_google_email
      keeper.restricted_content = true
      keeper.email_verified_at ||= Time.current
    end
  end
end
