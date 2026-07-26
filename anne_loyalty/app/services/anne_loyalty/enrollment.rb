module AnneLoyalty
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
        LoyaltyMember.lock.find_by(loyalty_program: program, owner:) ||
          LoyaltyMember.create!(loyalty_program: program, owner:, member_key:)
      end
    end

    private
      attr_reader :program, :owner, :member_key
  end
end
