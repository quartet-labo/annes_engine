module AnnesIntake
  module Flows
    class AnswerReader
      def self.call(run:, context:, action: :view)
        AccessPolicy.for_run(run, context).authorize!(action, run: run)
        raise Conflict unless run.submitted?
        run.step_runs.where.not(step_response_id: nil).includes(:step, form_version: :fields, step_response: { answers: [:field, { options: :field_option }, { attachments: { file_attachment: :blob } }] }).to_h do |step|
          reader = AnnesIntake::AnswerReader.new(step.step_response)
          [step.key, step.form_version.fields.to_h { |field| [field.key, reader[field.key]] }]
        end
      end
    end
  end
end
