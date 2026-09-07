module AnnesInquiry
  module Admin
    class AttachmentsController < ActionController::Base
      protect_from_forgery with: :exception
      include ActionController::Live
      include AdminAccess
      include DefinitionErrors

      def show
        submission = Submission.find(params[:submission_id])
        attachment = AnswerAttachment.where(answer_id: submission.answers.select(:id)).find(params[:id])
        return head :not_found unless attachment.file.attached?
        response.headers["Cache-Control"] = "private, no-store"
        send_stream(filename: attachment.file.filename.to_s, type: "application/octet-stream", disposition: "attachment") do |stream|
          attachment.file.download { |chunk| stream.write(chunk) }
        end
      end
    end
  end
end
