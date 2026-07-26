module AnneLoyalty
  class Error < StandardError; end
  class NotImplementedError < Error; end
  class InvalidSourceError < Error; end
  class InvalidEarningLocationError < Error; end
  class InsufficientPointsError < Error; end
  class AlreadyReversedError < Error; end
  class InactiveRewardError < Error; end
  class InvalidRedemptionTokenError < Error; end
  class InvalidRedemptionLocationError < Error; end
  class ExpiredRedemptionError < Error; end
  class AlreadyRedeemedError < Error; end
  class CanceledRedemptionError < Error; end
end
