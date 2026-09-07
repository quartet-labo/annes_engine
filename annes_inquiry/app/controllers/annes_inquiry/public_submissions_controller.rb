module AnnesInquiry
  class PublicSubmissionsController < ActionController::Base
    protect_from_forgery with: :exception
    helper AnnesInquiry::FormHelper
    before_action :require_public_endpoint

    def show
      load_form
      @version = @form.versions.published.first!
      @input = Input.new(@version, raw_values: {})
      @submission_token = SubmissionToken.issue(@version, identity: identity)
    end

    def create
      load_form
      adapter = AnnesInquiry.configuration.adapters[@form.key]
      context = adapter.prepare_context(self) if adapter&.respond_to?(:prepare_context)
      raw = params[:inquiry].is_a?(ActionController::Parameters) ? params[:inquiry].to_unsafe_h : (params[:inquiry] || {})
      result = SubmissionService.call(form: @form, token: params[:submission_token], identity: identity, raw_values: raw, adapter: adapter, context: context)
      if result.success?
        session[:inquiry_receipts] = (Array(session[:inquiry_receipts]) + [ result.submission.receipt_id ]).last(20)
        redirect_to completion_path(result.submission.receipt_id), status: :see_other
      else
        @input, @version = result.input, result.input.version
        return head :not_found unless @version
        if result.status == 409
          current = @form.versions.published.first
          old_fields = @version.fields.index_by(&:key)
          new_fields = current ? current.fields.index_by(&:key) : {}
          @definition_changes = {
            "追加された項目" => new_fields.keys - old_fields.keys,
            "削除された項目" => old_fields.keys - new_fields.keys,
            "設定が変更された項目" => (old_fields.keys & new_fields.keys).select do |key|
              old_fields[key].attributes.except("id", "form_version_id", "created_at", "updated_at") !=
                new_fields[key].attributes.except("id", "form_version_id", "created_at", "updated_at")
            end
          }
        end
        @submission_token = params[:submission_token]
        render :show, status: result.status
      end
    end

    def completion
      return head :not_found unless Array(session[:inquiry_receipts]).include?(params[:receipt_id])
      @submission = Submission.find_by!(receipt_id: params[:receipt_id])
    end

    private
      def require_public_endpoint
        head :not_found unless AnnesInquiry.configuration.public_endpoints_enabled
      end

      def load_form
        @form = Form.find_by!(key: params[:key], enabled: true)
      end

      def identity
        session[:inquiry_identity] ||= SecureRandom.uuid
      end
  end
end
