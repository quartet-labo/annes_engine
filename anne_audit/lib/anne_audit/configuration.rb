module AnneAudit
  class Configuration
    DEFAULT_METADATA_FILTER_KEYS = %i[
      password
      token
      code
      otp
      cookie
      secret
      credential
    ].freeze

    attr_accessor :raise_on_persistence_error, :metadata_filter_keys

    def initialize
      @raise_on_persistence_error = false
      @metadata_filter_keys = DEFAULT_METADATA_FILTER_KEYS.dup
    end
  end
end
