module AnnesIntake
  module Admin
    class VersionsController < ActionController::Base
      protect_from_forgery with: :exception
      include AdminAccess
      include ScopedDefinitionAccess
      include DefinitionErrors

      def show
        @version = definition_record(@definition_policy.scope(FormVersion.all).find(params[:id]))
      end

      def publish
        @version = definition_record(@definition_policy.scope(FormVersion.all).find(params[:id]))
        Definitions::PublishVersion.call(@version, context: @definition_context, expected_lock_version: params[:lock_version])
        redirect_to admin_version_path(@version), notice: "公開しました。", status: :see_other
      rescue Definitions::Error => error
        @operation_error = error.message
        render :show, status: :unprocessable_entity
      end

      def duplicate
        version = Definitions::CloneVersion.call(definition_record(@definition_policy.scope(FormVersion.all).find(params[:id])), context: @definition_context)
        redirect_to admin_version_path(version), notice: "編集用の下書きを作成しました。", status: :see_other
      end

      def destroy
        @version = definition_record(@definition_policy.scope(FormVersion.all).find(params[:id]))
        Definitions::DraftEditor.call(@version, context: @definition_context, expected_lock_version: params[:lock_version]) do |draft|
          raise Definitions::Error, "参照中の版は削除できません。" if Step.where(form_version_id: draft.id).exists?
          draft.destroy!
        end
        redirect_to admin_form_path(@version.form_id), status: :see_other
      end

      def preview
        @version = definition_record(@definition_policy.scope(FormVersion.all).find(params[:id]))
        raw = params[:intake].is_a?(ActionController::Parameters) ? params[:intake].to_unsafe_h : (params[:intake] || {})
        @input = Input.new(@version, raw_values: raw)
        status = request.post? && !@input.valid? ? :unprocessable_entity : :ok
        render :preview, status: status
      end

      def update
        @version = definition_record(@definition_policy.scope(FormVersion.all).find(params[:id]))
        Definitions::DraftEditor.call(@version, context: @definition_context, expected_lock_version: params[:lock_version]) do |draft|
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
