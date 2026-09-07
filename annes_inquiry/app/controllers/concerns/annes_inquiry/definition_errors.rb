module AnnesInquiry
  module DefinitionErrors
    extend ActiveSupport::Concern
    included do
      rescue_from ActiveRecord::StaleObjectError do
        render plain: "ほかの画面で更新されました。画面を開き直して確認してください。", status: :conflict
      end
      rescue_from Definitions::Error do |error|
        render plain: error.message, status: :unprocessable_entity
      end
      rescue_from ActiveRecord::RecordNotFound do
        head :not_found
      end
    end
  end
end
