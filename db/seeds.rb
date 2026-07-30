# frozen_string_literal: true

def seed_log(message)
  puts(message) unless Rails.env.test?
end

Setting.instance

admin_email = ENV["ADMIN_EMAIL"].presence

if admin_email.nil?
  seed_log("Seeds: ADMIN_EMAIL is not set, no admin created")
else
  admin = User.find_or_initialize_by(email: admin_email)
  if admin.new_record?
    admin.name = ENV.fetch("ADMIN_NAME", "Admin")
    admin.password = SecureRandom.base58(24)
  end

  admin.admin = true
  admin.restricted_content = true
  admin.google_email ||= ENV["ADMIN_GOOGLE_EMAIL"].presence || admin_email
  admin.email_verified_at ||= Time.current
  admin.save!

  seed_log("Seeds: admin #{admin.email}")
end
