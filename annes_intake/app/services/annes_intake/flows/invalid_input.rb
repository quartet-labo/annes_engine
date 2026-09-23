module AnnesIntake
  module Flows
    class InvalidInput < Error
      attr_reader :input
      def initialize(input)
        @input = input
        super(input.errors.full_messages.to_sentence)
      end
    end
  end
end
