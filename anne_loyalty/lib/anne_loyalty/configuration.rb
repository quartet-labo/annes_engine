module AnneLoyalty
  class Configuration
    attr_accessor :token_digest_secret

    def initialize
      @token_digest_secret = nil
    end
  end
end
