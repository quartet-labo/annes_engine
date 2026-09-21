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
          if params[:remove_step_id]
            draft.steps.find(params[:remove_step_id]).destroy!
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
        @inputs = @version.steps.to_h do |step|
          raw = params.fetch(:answers, {}).fetch(step.key, {})
          raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
          input = Input.new(step.form_version, raw_values: raw)
          input.valid? if request.post?
          [step.key, input]
        end
      end

      private
        def load_version
          @flow = Flow.find(params[:id])
          @version = @flow.versions.find(params[:version_id])
        end
    end
  end
end
