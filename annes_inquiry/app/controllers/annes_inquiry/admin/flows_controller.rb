module AnnesInquiry
  module Admin
    class FlowsController < ActionController::Base
      protect_from_forgery with: :exception
      include AdminAccess
      include FlowErrors
      helper FlowHelper

      def index
        @flows = Flow.order(:id)
      end
      def create
        flow = Flow.create!(params.require(:flow).permit(:key, :name))
        flow.versions.create!(number: 1, title: flow.name)
        redirect_to admin_flow_path(flow), status: :see_other
      end
      def show
        @flow = Flow.find(params[:id])
      end
      def update
        flow = Flow.find(params[:id])
        flow.with_lock { flow.update!(params.require(:flow).permit(:name, :enabled)) }
        redirect_to admin_flow_path(flow), status: :see_other
      end
      def duplicate
        flow = Flow.find(params[:id])
        source = flow.versions.find(params[:version_id])
        Flows::Definitions::CloneVersion.call(source)
        redirect_to admin_flow_path(flow), status: :see_other
      end
      def edit_version
        load_version
        Flows::Definitions::DraftEditor.call(@version, expected_lock_version: params[:lock_version]) do |draft|
          if params[:rule_step_id]
            step = draft.steps.find(params[:rule_step_id])
            if params[:remove_group_id]
              step.condition_groups.find(params[:remove_group_id]).destroy!
            elsif params[:remove_mapping_id]
              step.value_mappings.find(params[:remove_mapping_id]).destroy!
            elsif params[:condition]
              attrs = params.require(:condition).permit(:source_step_id, :field_id, :operator, :expected_value)
              group = params[:group_id].present? ? step.condition_groups.find(params[:group_id]) : step.condition_groups.create!
              group.conditions.create!(attrs)
            elsif params[:mapping]
              step.value_mappings.create!(params.require(:mapping).permit(:source_step_id, :source_field_id, :target_field_id))
            end
            Flows::Definitions::Validator.rules!(step)
          elsif params[:remove_step_id]
            step = draft.steps.find(params[:remove_step_id])
            if FlowCondition.where(source_step_id: step.id).exists? || FlowValueMapping.where(source_step_id: step.id).exists?
              raise Flows::Error, "このステップを参照する条件・引継ぎを先に削除してください。"
            end
            step.destroy!
          elsif params[:step]
            attrs = params.require(:step).permit(:key, :title, :position, :form_version_id)
            if params[:step_id]
              draft.steps.find(params[:step_id]).update!(attrs)
            else
              draft.steps.create!(attrs)
            end
          else
            draft.update!(params.require(:version).permit(:title))
          end
        end
        redirect_to admin_flow_path(@flow), status: :see_other
      end
      def publish
        load_version
        Flows::Definitions::PublishVersion.call(@version, expected_lock_version: params[:lock_version])
        redirect_to admin_flow_path(@flow), status: :see_other
      end
      def preview
        load_version
        raw = params.fetch(:answers, {})
        raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
        result = Flows::RouteEvaluator.preview(@version, raw)
        @steps = result.steps
        @inputs = @steps.to_h { |step| [step.key, result.inputs.fetch(step.id)] }
        @inputs.each_value { |input| input.errors.clear } unless request.post?
      end

      private
        def load_version
          @flow = Flow.find(params[:id])
          @version = @flow.versions.find(params[:version_id])
        end
    end
  end
end
