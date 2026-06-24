module AnneAdmin
  class AuthorizationAdapter
    attr_reader :block

    def initialize(block)
      @block = block
    end

    def authorized?(context)
      block.call(context)
    end
  end
end
