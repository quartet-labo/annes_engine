module AnnesIntake
  # Stable callback values for both review and persistence. No temporary IO or
  # partially constructed ActiveRecord instances escape the validation block.
  class RunPayload
    Attachment = Data.define(:filename, :byte_size, :content_type)
    def self.call(values)
      values.transform_values do |value|
        if value.is_a?(Array) && value.first.is_a?(AttachmentValidator::Upload)
          value.map { |upload| Attachment.new(filename: upload.filename.to_s, byte_size: upload.byte_size, content_type: upload.content_type) }
        else
          value
        end
      end
    end
  end
end
