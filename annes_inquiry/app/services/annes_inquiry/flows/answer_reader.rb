module AnnesInquiry
  module Flows
    class AnswerReader
      def self.call(run:, context:, action: :view)
        AccessPolicy.new(flow: run.flow, context: context).authorize!(action, run: run)
        raise Conflict unless run.submitted?
        run.step_runs.where.not(submission_id: nil).includes(:flow_step, form_version: :fields, submission: { answers: [:field, { options: :field_option }, { attachments: { file_attachment: :blob } }] }).to_h do |step|
          reader = AnnesInquiry::AnswerReader.new(step.submission)
          [step.key, step.form_version.fields.to_h { |field| [field.key, reader[field.key]] }]
        end
      end
    end
  end
end
