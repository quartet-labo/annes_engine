module AnneAudit
  class Reference
    def self.normalize(record)
      new(record).normalize
    end

    def initialize(record)
      @record = record
    end

    def normalize
      return {} if record.nil?
      return normalize_hash(record) if record.is_a?(Hash)

      {
        type: record.class.name,
        id: record_id,
        label: record_label
      }
    end

    private
      attr_reader :record

      def normalize_hash(value)
        hash = value.to_h

        {
          type: hash[:type] || hash["type"],
          id: hash[:id] || hash["id"],
          label: hash[:label] || hash["label"]
        }.compact.transform_values { |item| item.to_s }
      end

      def record_id
        return record.to_param.to_s if record.respond_to?(:to_param)
        return record.id.to_s if record.respond_to?(:id) && !record.id.nil?

        nil
      end

      def record_label
        if record.respond_to?(:audit_label)
          record.audit_label
        elsif record.respond_to?(:name)
          record.name
        elsif record.respond_to?(:email)
          record.email
        else
          record.to_s
        end.to_s
      end
  end
end
