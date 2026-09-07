module AnnesInquiry
  module Admin
    class SubmissionsController < ActionController::Base
      protect_from_forgery with: :exception
      include AdminAccess
      include DefinitionErrors

      def show
        @submission = Submission.includes(form_version: { fields: :options }).find(params[:id])
        @reader = AnswerReader.new(@submission)
        @host_link = AnnesInquiry.configuration.admin_submission_link&.call(self, @submission)
        @notifications = @submission.notification_requests.order(:id)
        @notification_actions = @notifications.to_h { |notification| [notification.id, AnnesInquiry.configuration.admin_notification_action&.call(self, notification)] }
        response.headers["Cache-Control"] = "private, no-store"
      end

      def index
        @forms = Form.order(:name)
        @page = Integer(params[:page].presence || 1, exception: false) || 1
        @filters = params[:filters].is_a?(ActionController::Parameters) ? params[:filters].values.map { |item| item.is_a?(ActionController::Parameters) ? item.to_unsafe_h : item } : []
        @submissions = SubmissionQuery.new(form_id: params[:form_id], version_id: params[:version_id], from: params[:from], to: params[:to], filters: @filters, page: @page).call.to_a
      rescue ArgumentError, KeyError => error
        @query_error = error.message
        @submissions = []
        render :index, status: :unprocessable_entity
      end
    end
  end
end
