Rails.application.config.filter_parameters += [
  :passw,
  :email,
  :secret,
  :token,
  :_key,
  :crypt,
  :salt,
  :certificate,
  :otp,
  :ssn,
  :cvv,
  :cvc,
  /\Aphotos?\z/,
  /\Areading_text\.body\z/,
  /\Ahandover\./
]
