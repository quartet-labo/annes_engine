module AnnesIntake
  module Definitions
    class Disable
      def self.call(record:, expected_lock_version:, context:)
        raise ArgumentError unless record.is_a?(Form) || record.is_a?(Flow)
        DefinitionPolicy.lock(record, context: context) do
          record.class.find(record.id).with_lock do |locked|
            record.reload
            DefinitionPolicy.new(context: context).authorize!(record)
            raise ActiveRecord::StaleObjectError.new(record, "update") unless record.lock_version == Integer(expected_lock_version, exception: false)
            record.update!(enabled: false)
            record
          end
        end
      end
    end
  end
end
