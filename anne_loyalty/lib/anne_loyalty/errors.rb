module AnneLoyalty
  class Error < StandardError; end
  class NotImplementedError < Error; end
  class InvalidSourceError < Error; end
  class InsufficientPointsError < Error; end
  class AlreadyReversedError < Error; end
end
