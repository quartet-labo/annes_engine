module AnnesInquiry
  class AnswerWriter
    def self.upload_files(values)
      values.each_with_object({}) do |(key, value), blobs|
        next unless value.is_a?(Array) && value.first.is_a?(AttachmentValidator::Upload)
        blobs[key] = value.map do |file|
          file.upload.tempfile.rewind
          blob = ActiveStorage::Blob.create_after_unfurling!(io: file.upload.tempfile, filename: file.filename,
            content_type: file.content_type, identify: false, metadata: { annes_inquiry: true })
          UploadRollbackCleanup.register(blob)
          blob.upload_without_unfurling(file.upload.tempfile)
          blob
        end
      end
    end

    def self.call(submission, values, blobs:)
      submission.form_version.fields.each do |field|
        value = values[field.key]
        next if value.nil? || value == "" || value == []
        attributes = { field: field, form_version: submission.form_version, value_type: field.value_type }
        attributes["#{field.value_type}_value"] = value unless field.choice? || field.value_type == "attachment"
        answer = submission.answers.create!(attributes)
        if field.choice?
          Array(value).each do |selected|
            answer.options.create!(field: field, value_type: field.value_type, field_option: field.options.find_by!(value: selected))
          end
        elsif field.value_type == "attachment"
          blobs.fetch(field.key).each_with_index do |blob, position|
            answer.attachments.create!(field: field, value_type: "attachment", position: position, file: blob)
          end
        end
      end
    end
  end
end
