module AnnesInquiry
  module FlowErrors
    extend ActiveSupport::Concern
    included do
      rescue_from Flows::Error, AnnesInquiry::Definitions::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, with: ->(error) { render plain: error.message, status: :unprocessable_entity }
      rescue_from Flows::Forbidden, with: -> { head :forbidden }
      rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
      rescue_from Flows::Conflict, ActiveRecord::StaleObjectError, with: ->(error) { render plain: error.message.presence || "操作が競合しました。画面を開き直してください。", status: :conflict }
    end
  end
end
