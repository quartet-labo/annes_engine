module AnnesInquiry
  module Admin
    class VersionsController < ActionController::Base
      protect_from_forgery with: :exception
      include AdminAccess
      include DefinitionErrors

      def show
        @version = FormVersion.find(params[:id])
      end

      def publish
        @version = FormVersion.find(params[:id])
        Definitions::PublishVersion.call(@version, expected_lock_version: params[:lock_version])
        redirect_to admin_version_path(@version), notice: "公開しました。", status: :see_other
      rescue Definitions::Error => error
        @operation_error = error.message
        render :show, status: :unprocessable_entity
      end

      def duplicate
        version = Definitions::CloneVersion.call(FormVersion.find(params[:id]))
        redirect_to admin_version_path(version), notice: "編集用の下書きを作成しました。", status: :see_other
      end

      def destroy
        @version = FormVersion.find(params[:id])
        Definitions::DraftEditor.call(@version, expected_lock_version: params[:lock_version]) { |draft| draft.destroy! }
        redirect_to admin_form_path(@version.form_id), status: :see_other
      end

      def preview
        @version = FormVersion.find(params[:id])
        raw = params[:inquiry].is_a?(ActionController::Parameters) ? params[:inquiry].to_unsafe_h : (params[:inquiry] || {})
        @input = Input.new(@version, raw_values: raw)
        status = request.post? && !@input.valid? ? :unprocessable_entity : :ok
        render :preview, status: status
      end

      def update
        @version = FormVersion.find(params[:id])
        Definitions::DraftEditor.call(@version, expected_lock_version: params[:lock_version]) do |draft|
          @version = draft
          draft.update!(params.require(:version).permit(:title, :description, :submit_label, :completion_message))
        end
        redirect_to admin_version_path(@version), status: :see_other
      rescue ActiveRecord::RecordInvalid
        render :show, status: :unprocessable_entity
      end
    end
  end
end
