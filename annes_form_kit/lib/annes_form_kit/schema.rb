module AnnesFormKit
  module Immutable
    def self.copy(value)
      case value
      when Hash then value.to_h { |key, item| [copy(key), copy(item)] }.freeze
      when Array then value.map { |item| copy(item) }.freeze
      when String then value.dup.freeze
      else value.frozen? ? value : value.dup.freeze
      end
    end
  end

  class Spec
    def initialize(**attributes)
      unknown = attributes.keys - self.class::DEFAULTS.keys
      raise ArgumentError, "Unknown schema attributes: #{unknown.join(', ')}" if unknown.any?
      @attributes = Immutable.copy(self.class::DEFAULTS.merge(attributes))
      freeze
    end
    def [](key) = @attributes[key.to_sym]
    def to_h = @attributes.dup
    def self.attributes(defaults)
      const_set(:DEFAULTS, defaults.freeze)
      defaults.each_key { |key| define_method(key) { @attributes[key] } }
    end
  end
  class OptionSpec < Spec
    attributes value: nil, label: nil, position: 0
  end
  class FileTypeSpec < Spec
    attributes extension: nil, content_type: nil
  end
  class FieldSpec < Spec
    attributes key: nil, label: nil, value_type: "text", widget: "text", position: 0,
      required: false, must_be_true: false, placeholder: nil, help_text: nil,
      constraints: {}, options: [], file_types: []
    TypeRegistry::SETTINGS.values.flatten.uniq.each do |key|
      define_method(key) { constraints.key?(key) ? constraints[key] : constraints[key.to_sym] }
    end
    def [](key)
      self.class::DEFAULTS.key?(key.to_sym) ? super : (constraints.key?(key.to_s) ? constraints[key.to_s] : constraints[key.to_sym])
    end
    def choice? = %w[single_choice multiple_choice].include?(value_type)
  end
  class FormSchema < Spec
    attributes title: nil, description: nil, submit_label: "送信", completion_message: nil, fields: []
  end
  Result = Data.define(:values, :errors) do
    def valid? = errors.empty?
  end
  class UploadSource
    attr_reader :filename
    def initialize(io:, filename:)
      @io, @filename = io, filename
    end
    def io = @io.respond_to?(:call) ? @io.call : @io
  end
  UploadInspection = Data.define(:source, :checksum, :byte_size, :filename, :content_type)
end
