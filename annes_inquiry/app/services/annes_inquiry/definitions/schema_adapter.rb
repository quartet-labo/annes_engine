module AnnesInquiry
  module Definitions
    class SchemaAdapter
      def self.call(version)
        AnnesFormKit::FormSchema.new(title: version.title, description: version.description,
          submit_label: version.submit_label, completion_message: version.completion_message,
          fields: version.fields.includes(:options, :file_types).map { |field| self.field(field) })
      end
      def self.field(field)
        attributes = AnnesFormKit::FieldSpec::DEFAULTS.keys - [:constraints, :options, :file_types]
        AnnesFormKit::FieldSpec.new(**attributes.to_h { |key| [key, field.public_send(key)] },
          constraints: TypeRegistry::SETTINGS.values.flatten.uniq.to_h { |key| [key, field[key]] },
          options: field.options.map { |option| AnnesFormKit::OptionSpec.new(value: option.value, label: option.label, position: option.position) },
          file_types: field.file_types.map { |type| AnnesFormKit::FileTypeSpec.new(extension: type.extension, content_type: type.content_type) })
      end
    end
  end
end
