require "anne_loyalty/version"
require "anne_loyalty/configuration"
require "anne_loyalty/errors"
require "anne_loyalty/engine" if defined?(Rails::Engine)

module AnneLoyalty
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def enroll!(**)
      raise NotImplementedError, "AnneLoyalty.enroll! is implemented in Task 1.3"
    end

    def quote_earn(**)
      raise NotImplementedError, "AnneLoyalty.quote_earn is implemented in Task 1.3"
    end

    def earn!(**)
      raise NotImplementedError, "AnneLoyalty.earn! is implemented in Task 1.3"
    end

    def balance_for(**)
      raise NotImplementedError, "AnneLoyalty.balance_for is implemented in Task 1.3"
    end

    def redeem_reward!(**)
      raise NotImplementedError, "AnneLoyalty.redeem_reward! is implemented in Task 2.2"
    end

    def confirm_redemption!(**)
      raise NotImplementedError, "AnneLoyalty.confirm_redemption! is implemented in Task 2.2"
    end

    def reverse!(**)
      raise NotImplementedError, "AnneLoyalty.reverse! is implemented in Task 1.3"
    end
  end
end
