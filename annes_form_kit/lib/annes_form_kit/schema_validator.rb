module AnnesFormKit
  class SchemaValidator
    def self.call(schema)
      new.validate!(schema)
      schema
    end
    def validate!(schema)
      raise ArgumentError, "フォームのタイトルが必要です" unless schema.title.is_a?(String) && schema.title.present?
      raise ArgumentError, "項目を1つ以上追加してください。" unless schema.fields.is_a?(Array) && schema.fields.any?
      %i[description completion_message].each { |key| string!(schema[key], optional: true) }
      string!(schema.submit_label)
      raise ArgumentError, "項目の形式が不正です" unless schema.fields.all? { |field| field.is_a?(FieldSpec) }
      keys = schema.fields.map(&:key)
      raise ArgumentError, "項目キーが重複しています" unless keys.uniq == keys
      schema.fields.each do |field|
        raise ArgumentError, "項目キーが不正です" unless field.key.is_a?(String) && field.key.match?(/\A[a-z][a-z0-9_]{0,63}\z/)
        raise ArgumentError, "ラベルが必要です" unless field.label.is_a?(String) && field.label.present?
        raise ArgumentError, "値の型が不正です" unless TypeRegistry::WIDGETS.key?(field.value_type)
        raise ArgumentError, "必須指定が不正です" unless [true, false].include?(field.required) && [true, false].include?(field.must_be_true)
        raise ArgumentError, "順番が不正です" unless field.position.is_a?(Integer) && field.position >= 0
        raise ArgumentError, "未定義の制約です" if (field.constraints.keys.map(&:to_s) - TypeRegistry::SETTINGS.values.flatten).any?
        %i[placeholder help_text].each { |key| string!(field[key], optional: true) }
        field.constraints.each do |key, value|
          next if value.nil?
          valid = case key.to_s
          when /_(length|selections|files|file_bytes)\z/ then value.is_a?(Integer) && value >= 0
          when /_numeric\z/ then value.is_a?(Numeric) && value.real? && value.finite?
          when /_datetime\z/ then value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
          when /_date\z/ then value.is_a?(Date) && !value.is_a?(DateTime)
          when "normalizer_key", "format_key" then value.is_a?(String)
          else false
          end
          raise ArgumentError, "制約の型が不正です: #{key}" unless valid
        end
        %w[length numeric date datetime selections].each do |kind|
          min, max = field["min_#{kind}"], field["max_#{kind}"]
          raise ArgumentError, "最小値が最大値を超えています" if min && max && min > max
        end
        %w[min_length max_length min_selections max_selections].each do |key|
          value = field[key]
          raise ArgumentError, "制約は非負整数で指定してください" if value && (!value.is_a?(Integer) || value < 0)
        end
        %w[max_files max_file_bytes].each do |key|
          value = field[key]
          raise ArgumentError, "添付上限は正の整数で指定してください" if value && (!value.is_a?(Integer) || value <= 0)
        end
        options = field.options.map(&:value)
        raise ArgumentError, "選択肢が重複しています" unless options.uniq == options
        field.options.each do |option|
          raise ArgumentError, "選択肢が不正です" unless option.value.is_a?(String) && option.value.present? && option.label.is_a?(String) && option.label.present? && option.position.is_a?(Integer) && option.position >= 0
        end
        field.file_types.each do |type|
          raise ArgumentError, "許可形式が不正です" unless type.extension.is_a?(String) && type.extension.match?(/\A\.[a-z0-9]+\z/) && (type.content_type.nil? || type.content_type.is_a?(String))
        end
        validate_field!(field)
      end
    end
    private
      def string!(value, optional: false)
        raise ArgumentError, "表示属性は文字列で指定してください" unless (optional && value.nil?) || value.is_a?(String)
      end
      def validate_field!(field)
        allowed_widgets = TypeRegistry::WIDGETS.fetch(field.value_type, [])
        fail_field!(field, "入力形式が値の型に対応していません") unless allowed_widgets.include?(field.widget)
        if field.placeholder.present? && !TypeRegistry::PLACEHOLDER_WIDGETS.include?(field.widget)
          fail_field!(field, "この入力形式にはプレースホルダーを設定できません")
        end
        settings = TypeRegistry::SETTINGS.fetch(field.value_type, [])
        TypeRegistry::SETTINGS.values.flatten.uniq.each do |setting|
          fail_field!(field, "#{setting}はこの型に設定できません") if field[setting].present? && !settings.include?(setting)
        end
        if field.normalizer_key.present? && !TypeRegistry::NORMALIZERS.include?(field.normalizer_key)
          fail_field!(field, "未登録の正規化処理です")
        end
        if field.format_key.present? && !TypeRegistry::FORMATS.include?(field.format_key)
          fail_field!(field, "未登録の形式検証です")
        end
        if field.must_be_true && field.value_type != "boolean"
          fail_field!(field, "同意必須は真偽値にだけ指定できます")
        end
        if field.value_type == "boolean" && field.required && !field.must_be_true && field.widget == "checkbox"
          fail_field!(field, "回答必須の真偽値にはラジオボタンを使ってください")
        end
        if field.value_type == "integer" && [field.min_numeric, field.max_numeric].compact.any? { |value| value.frac.nonzero? }
          fail_field!(field, "整数の範囲には整数を指定してください")
        end
        if field.required && ((field.value_type == "text" && field.max_length == 0) ||
            (field.value_type == "multiple_choice" && field.max_selections == 0))
          fail_field!(field, "必須回答を満たせる上限を設定してください")
        end
        if field.choice?
          fail_field!(field, "選択肢を追加してください") if field.options.empty?
          if field.min_selections && field.min_selections > field.options.size
            fail_field!(field, "最低選択数が選択肢数を超えています")
          end
        elsif field.options.any?
          fail_field!(field, "選択式以外には選択肢を設定できません")
        end
        if field.value_type == "attachment"
          unless field.max_files.present? && field.max_file_bytes.present? && field.file_types.any?
            fail_field!(field, "添付上限と許可形式が必要です")
          end
        elsif field.file_types.any?
          fail_field!(field, "添付以外には許可形式を設定できません")
        end
      end

      def fail_field!(field, message)
        raise ArgumentError, "#{field.label}: #{message}"
      end
  end
end
