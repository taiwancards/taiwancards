# frozen_string_literal: true

namespace(:accounts) do
  desc("Leave only the owner's Google account, renumber it to 1 and restart ids from 2 (CONFIRM=yes)")
  task(consolidate: :environment) do
    owner_email = User.owner_google_email
    abort("ADMIN_GOOGLE_EMAIL is unset, so there is no owner to consolidate onto.") if owner_email.nil?

    keeper = User.find_by(google_email: owner_email)
    doomed = User.where.not(google_email: owner_email)

    if keeper.nil?
      abort("No account signs in as #{owner_email}. Sign in with it once, then run this again.")
    end

    unless ENV["CONFIRM"] == "yes"
      abort(
        <<~USAGE
          This deletes #{doomed.count} account(s) and everything attached to them.

          Keeping : #{keeper.email} (id #{keeper.id})
          Deleting: #{doomed.pluck(:email).join(", ").presence || "nothing"}

          Run:
            CONFIRM=yes rake accounts:consolidate
        USAGE
      )
    end

    result = Accounts::Consolidate.new(owner_email).call
    pp(result)
  end
end
