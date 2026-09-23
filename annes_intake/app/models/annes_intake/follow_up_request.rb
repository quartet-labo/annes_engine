module AnnesIntake
  class FollowUpRequest < ApplicationRecord
    belongs_to :root_run, class_name: "AnnesIntake::Run"
    belongs_to :definition_version, class_name: "AnnesIntake::FlowVersion"
    belongs_to :source_version, class_name: "AnnesIntake::FlowVersion"
    belongs_to :response_run, class_name: "AnnesIntake::Run", optional: true
    enum :status, {draft: "draft", issued: "issued", answered: "answered", cancelled: "cancelled"}, validate: true
    validates :title, :due_at, :request_key, presence: true
    validates :number, uniqueness: {scope: :root_run_id}, numericality: {only_integer: true, greater_than: 0}
    validates :request_key, uniqueness: {scope: :root_run_id}, format: {with: /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/}
    validate :valid_root, on: :create
    def valid_root
      errors.add(:root_run, "は初回の受付済みデータが必要です") unless root_run&.submitted? && !root_run.follow_up_request
    end
    before_update :preserve_issued_definition
    before_destroy { throw :abort }
    def expired? = !answered? && due_at <= Time.current

    private
      def preserve_issued_definition
        immutable = %w[root_run_id source_version_id request_key number custom]
        throw :abort if status_in_database != "draft" || immutable.any? { |name| will_save_change_to_attribute?(name) }
      end
  end
end
