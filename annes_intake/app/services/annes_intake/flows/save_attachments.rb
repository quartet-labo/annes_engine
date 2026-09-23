module AnnesIntake
  module Flows
    class SaveAttachments
      def self.call(step, field, uploads, retained_ids)
        records = step.draft_attachments.where(field: field).to_a
        unless retained_ids.nil?
          raise Forbidden unless retained_ids.is_a?(Array) && retained_ids.all? { |id| id.is_a?(String) && id.match?(/\A[0-9]+\z/) }
          ids = retained_ids.reject(&:blank?).map(&:to_i)
          raise Forbidden unless ids.uniq.size == ids.size && (ids - records.map(&:id)).empty?
          records = records.select { |record| ids.include?(record.id) }
        end
        input = Input.new(step.form_version, raw_values: {})
        if field.max_files && records.size + uploads.size > field.max_files
          input.errors.add(field.key, "のファイル件数が上限を超えています")
          raise InvalidInput.new(input)
        end
        validated = AttachmentValidator.call(field, uploads, input.errors)
        raise InvalidInput.new(input) if input.errors.any?
        blobs = AnswerWriter.upload_files({field.key => validated}).fetch(field.key, [])
        keep = records.map(&:id)
        step.draft_attachments.where(field: field).where.not(id: keep).destroy_all
        # Reassign positions without transient collisions.
        records.each_with_index { |record, i| record.update!(position: 1_000_000 + i) }
        records.each_with_index { |record, i| record.update!(position: i) }
        blobs.each_with_index do |blob, i|
          step.draft_attachments.create!(field: field, form_version_id: step.form_version_id, position: records.size + i, file: blob)
        end
      end
    end
  end
end
