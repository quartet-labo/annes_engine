module AnnesAdmin
  class AuthenticationAdapter
    attr_reader :block

    def initialize(block)
      @block = block
    end

    def authenticate(controller)
      block.call(controller)
    end
  end
end
