AnneLoyalty.configure do |config|
  config.token_digest_secret = Rails.application.secret_key_base
end
