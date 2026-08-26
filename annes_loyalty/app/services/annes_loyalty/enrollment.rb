module AnnesLoyalty
  class Enrollment
    def self.call(program:, owner:, member_key:)
      new(program:, owner:, member_key:).call
    end

    def initialize(program:, owner:, member_key:)
      @program = program
      @owner = owner
      @member_key = member_key
    end

    def call
      LoyaltyMember.transaction do
        program.lock!
        find_existing_member ||
          LoyaltyMember.create!(loyalty_program: program, owner:, member_key:)
      end
    rescue ActiveRecord::RecordNotUnique
      find_existing_member || raise
    end

    private
      attr_reader :program, :owner, :member_key

      def find_existing_member
        LoyaltyMember.find_by(loyalty_program: program, owner:)
      end
  end
end
