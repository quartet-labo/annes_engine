module AnnesInquiry
  class Input
    include ActiveModel::Model
    attr_reader :version, :raw_values, :values, :time_zone

    def initialize(version, raw_values:, adapter: nil, context: nil, time_zone: "UTC", enrichment_values: nil)
      @version, @raw_values, @adapter, @context, @time_zone = version, raw_values, adapter, context, time_zone
      @values = {}
      @enrichment_values = enrichment_values
    end

    def valid?(*args)
      errors.clear
      @values = {}
      fields = version.fields.includes(:options, :file_types).to_a
      return false unless valid_shape?(fields)
      merge_errors(@adapter.validate_raw_input(raw_values, @context)) if @adapter&.respond_to?(:validate_raw_input)
      fields.each do |field|
        begin
          values[field.key] = ValueConverter.call(field, raw_values[field.key], time_zone: time_zone)
        rescue ArgumentError
          errors.add(field.key, "の形式または桁数が正しくありません")
        end
      end
      if @enrichment_values
        @values = values.merge(@enrichment_values)
      elsif @adapter&.respond_to?(:enrich_input)
        @values = @adapter.enrich_input(values, @context)
      end
      fields.each { |field| validate_value(field, values[field.key]) unless errors[field.key].any? }
      merge_errors(@adapter.validate_input(values, @context)) if @adapter&.respond_to?(:validate_input)
      errors.empty?
    end

    def read_attribute_for_validation(key)
      values[key.to_s]
    end

    private
      def valid_shape?(fields)
        schema = AnnesFormKit::FormSchema.new(fields: fields.map { |field| Definitions::SchemaAdapter.field(field) })
        raw = raw_values.is_a?(Hash) ? raw_values.transform_values { |value|
          value.is_a?(Array) ? value.map { |item| item.is_a?(ActionDispatch::Http::UploadedFile) ? AnnesFormKit::UploadSource.new(io: -> { item.tempfile }, filename: item.original_filename) : item } : value
        } : raw_values
        result = AnnesFormKit::ShapeValidator.call(schema: schema, raw_values: raw)
        merge_errors(result.errors)
        result.valid?
      end

      def validate_value(field, value)
        if field.value_type == "attachment"
          missing = value.nil? || value == "" || value == []
          errors.add(field.key, "を入力してください") if field.required && missing
          values[field.key] = AttachmentValidator.call(field, value, errors) unless missing
        else
          schema = AnnesFormKit::FormSchema.new(fields: [Definitions::SchemaAdapter.field(field)])
          result = AnnesFormKit::ValueValidator.call(schema: schema, values: {field.key => value})
          values[field.key] = result.values[field.key] if values.key?(field.key)
          merge_errors(result.errors)
        end
      end

      def merge_errors(messages)
        (messages || {}).each { |key, items| Array(items).each { |message| errors.add(key, message) } }
      end
  end
end
