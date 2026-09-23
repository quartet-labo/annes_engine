module AnnesIntake
  module Flows
    class DraftReader
      def self.call(step)
        answers = step.association(:draft_answers).loaded? ? step.draft_answers : step.draft_answers.includes(:field, :values)
        answers.to_h do |answer|
          [answer.field.key, answer.field.value_type == "multiple_choice" ? answer.values.map(&:raw_value) : answer.raw_value]
        end
      end

      # Files are revalidated from storage, never accepted from a client blob id.
      # Tempfiles stay open for the entire validation/write block.
      def self.with_input(step, raw_values: call(step), &block)
        attachments = step.draft_attachments.includes(:field, file_attachment: :blob).to_a
        open_files(attachments, raw_values.deep_dup, {}) do |raw, blobs|
          input = Input.new(step.form_version, raw_values: raw)
          yield input, blobs
        end
      end

      def self.open_files(attachments, raw, blobs, &block)
        return yield(raw, blobs) if attachments.empty?
        attachment, *remaining = attachments
        key = attachment.field.key
        blob = attachment.file.blob
        blob.open do |file|
          upload = ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: blob.filename.to_s, type: blob.content_type)
          raw[key] = Array(raw[key]) + [upload]
          blobs[key] = Array(blobs[key]) + [blob]
          open_files(remaining, raw, blobs, &block)
        end
      end
      private_class_method :open_files
    end
  end
end
