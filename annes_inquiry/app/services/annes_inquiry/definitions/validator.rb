module AnnesInquiry
  module Definitions
    class Validator
      def initialize(version)
        @version = version
      end

      def validate!
        raise Error, version.errors.full_messages.to_sentence unless version.valid?
        raise Error, "項目を1つ以上追加してください。" unless version.fields.exists?

        version.fields.includes(:options, :file_types).each do |field|
          validate_field!(field)
          validate_history!(field)
        end
      end

      private
        attr_reader :version

        def validate_field!(field)
          fail_field!(field, field.errors.full_messages.to_sentence) unless field.valid?
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

        def validate_history!(field)
          history = Field.where(form_version_id: version.form.versions.where(status: %w[published retired]).select(:id), key: field.key)
          return unless history.exists?
          fail_field!(field, "公開済みの項目キーの型は変更できません") if history.where.not(value_type: field.value_type).exists?
          previous = version.form.versions.where.not(status: "draft").order(number: :desc).first
          fail_field!(field, "削除済みの項目キーは再利用できません") if previous && !previous.fields.exists?(key: field.key)
        end

        def fail_field!(field, message)
          raise Error, "#{field.label}: #{message}"
        end
    end
  end
end
