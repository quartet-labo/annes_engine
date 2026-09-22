module AnnesFormKit
  module Renderer
    VIEW_PATH = File.expand_path("../../views", __dir__).freeze
    def self.field_attributes(field, input, scope:)
      id = "#{scope}_#{field.key}".gsub(/[^a-zA-Z0-9_-]/, "_")
      {id: id, required: field.required, placeholder: field.placeholder,
       aria: {describedby: "#{id}_help #{id}_errors", invalid: Array(input.errors[field.key]).any? ? "true" : nil}}
    end
  end
end
