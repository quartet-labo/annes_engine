module AnnesIntake
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
          AnnesFormKit::SchemaValidator.call(AnnesFormKit::FormSchema.new(title: version.title,
            fields: [SchemaAdapter.field(field)]))
        rescue ArgumentError => error
          raise Error, error.message
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
