require "openssl"
require "securerandom"

module AnnesLoyalty
  class RedemptionToken
    def self.generate
      SecureRandom.urlsafe_base64(32)
    end

    def self.digest(token)
      OpenSSL::HMAC.hexdigest("SHA256", digest_secret, token.to_s)
    end

    def self.digest_secret
      AnnesLoyalty.configuration.token_digest_secret.presence ||
        Rails.application.secret_key_base ||
        "anne-loyalty-test-token-secret"
    end
  end
end
