module AnnesFormKit
  class ErrorBag
    def initialize = @messages = {}
    def add(key, message) = (@messages[key.to_s] ||= []) << message
    def [](key) = @messages.fetch(key.to_s, [])
    def empty? = @messages.empty?
    def to_h = @messages.transform_values(&:dup)
  end
  class Validation
    attr_reader :raw_values, :values, :errors
    def initialize(raw_values: nil, values: {})
      @raw_values, @values, @errors = raw_values, values.dup, ErrorBag.new
    end
    def shape(fields)
      valid_shape?(fields)
      Result.new(values: raw_values, errors: errors.to_h)
    end
    def typed(fields)
      fields.each { |field| validate_value(field, values[field.key]) }
      Result.new(values: values, errors: errors.to_h)
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
            value.nil? || (value.is_a?(Array) && value.all? { |item| item.is_a?(String) || (field.value_type == "attachment" && item.is_a?(UploadSource)) })
          else
            value.nil? || value.is_a?(String)
          end
          errors.add(field.key, "の入力形式が正しくありません") unless valid
          validate_text_content(field, value) if valid && field.value_type == "text" && value
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
          validate_text_content(field, value)
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
          result = AttachmentInspector.call(field: field, uploads: value)
          values[field.key] = result.values
          result.errors.each { |key, messages| messages.each { |message| errors.add(key, message) } }
        end
      end

      def validate_text_content(field, value)
        errors.add(field.key, "に使用できない文字が含まれています") if value.include?("\0")
      end

      def check_bounds(field, value, kind)
        minimum, maximum = field["min_#{kind}"], field["max_#{kind}"]
        errors.add(field.key, "は#{minimum}以上にしてください") if minimum && value < minimum
        errors.add(field.key, "は#{maximum}以下にしてください") if maximum && value > maximum
      end

  end
  class ShapeValidator
    def self.call(schema:, raw_values:)
      Validation.new(raw_values: raw_values).shape(schema.fields)
    end
  end
  class ValueValidator
    def self.call(schema:, values:)
      Validation.new(values: values).typed(schema.fields)
    end
  end
end
