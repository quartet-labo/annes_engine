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
        unless raw_values.is_a?(Hash) && raw_values.keys.all? { |key| key.is_a?(String) }
          errors.add(:base, "入力の形式が正しくありません")
          return false
        end
        errors.add(:base, "未定義の項目が含まれています") if (raw_values.keys - fields.map(&:key)).any?
        fields.each do |field|
          value = raw_values[field.key]
          valid = if %w[multiple_choice attachment].include?(field.value_type)
            value.nil? || (value.is_a?(Array) && value.all? { |item| item.is_a?(String) || (field.value_type == "attachment" && item.is_a?(ActionDispatch::Http::UploadedFile)) })
          else
            value.nil? || value.is_a?(String)
          end
          errors.add(field.key, "の入力形式が正しくありません") unless valid
        end
        errors.empty?
      end

      def validate_value(field, value)
        missing = value.nil? || value == "" || value == []
        errors.add(field.key, "を入力してください") if field.required && missing
        errors.add(field.key, "への同意が必要です") if field.must_be_true && value != true
        return if missing

        case field.value_type
        when "text"
          check_bounds(field, value.length, :length)
          if field.format_key == "email" && !URI::MailTo::EMAIL_REGEXP.match?(value)
            errors.add(field.key, "のメールアドレスが正しくありません")
          end
        when "integer", "decimal" then check_bounds(field, value, :numeric)
        when "date" then check_bounds(field, value, :date)
        when "datetime" then check_bounds(field, value, :datetime)
        when "single_choice", "multiple_choice"
          selected = Array(value)
          values[field.key] = selected.sort if field.value_type == "multiple_choice"
          allowed = field.options.map(&:value)
          errors.add(field.key, "に未定義の選択肢が含まれています") if (selected - allowed).any?
          errors.add(field.key, "に重複した選択肢があります") if selected.uniq.size != selected.size
          check_bounds(field, selected.size, :selections) if field.value_type == "multiple_choice"
        when "attachment"
          values[field.key] = AttachmentValidator.call(field, value, errors)
        end
      end

      def check_bounds(field, value, kind)
        minimum, maximum = field["min_#{kind}"], field["max_#{kind}"]
        errors.add(field.key, "は#{minimum}以上にしてください") if minimum && value < minimum
        errors.add(field.key, "は#{maximum}以下にしてください") if maximum && value > maximum
      end

      def merge_errors(messages)
        (messages || {}).each { |key, items| Array(items).each { |message| errors.add(key, message) } }
      end
  end
end
