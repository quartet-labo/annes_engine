require "annes_loyalty/version"
require "annes_loyalty/configuration"
require "annes_loyalty/errors"
require "annes_loyalty/engine" if defined?(Rails::Engine)

module AnnesLoyalty
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
      Enrollment.call(**)
    end

    def quote_earn(**)
      EarnQuote.call(**)
    end

    def earn!(**)
      PointEarner.call(**)
    end

    def balance_for(**)
      BalanceReader.call(**)
    end

    def redeem_reward!(**)
      RewardRedemptionIssuer.call(**)
    end

    def confirm_redemption!(**)
      RedemptionConfirmer.call(**)
    end

    def reverse!(**)
      LedgerReverser.call(**)
    end
  end
end
