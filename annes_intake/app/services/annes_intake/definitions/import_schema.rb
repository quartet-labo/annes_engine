module AnnesIntake
  module Definitions
    class ImportSchema
      def self.call(document:, context:)
        policy = DefinitionPolicy.new(context: context)
        policy.authorize!(nil)
        schema = AnnesFormKit::SchemaCodec.load(document)
        Form.transaction do
          form = Form.create!(name: schema.title)
          policy.authorize!(form)
          version = form.versions.create!(number: 1, **schema.to_h.except(:fields))
          schema.fields.each do |spec|
            attributes = spec.to_h.except(:options, :file_types, :constraints).merge(spec.constraints)
            field = version.fields.create!(attributes)
            spec.options.each { |option| field.options.create!(option.to_h) }
            spec.file_types.each { |type| field.file_types.create!(type.to_h) }
          end
          version
        end
      end
    end
  end
end
