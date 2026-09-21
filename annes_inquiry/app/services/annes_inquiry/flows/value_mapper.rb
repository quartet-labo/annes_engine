module AnnesInquiry
  module Flows
    class ValueMapper
      def self.call(definition, raw, values)
        definition.value_mappings.includes(:source_field, :target_field).each_with_object(raw.deep_dup) do |mapping, result|
          value = values.dig(mapping.source_step_id, mapping.source_field.key)
          result[mapping.target_field.key] = serialize(value)
        end
      end

      def self.serialize(value)
        case value
        when nil then nil
        when Array then value.map { |item| serialize(item) }
        when BigDecimal then value.to_s("F")
        when Time, ActiveSupport::TimeWithZone then value.utc.strftime("%Y-%m-%dT%H:%M:%S.%6N")
        when Date then value.iso8601
        else value.to_s
        end
      end
    end
  end
end
