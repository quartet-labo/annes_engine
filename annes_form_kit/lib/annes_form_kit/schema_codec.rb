module AnnesFormKit
  class SchemaCodec
    LIMIT = 1024 * 1024
    def self.dump(schema)
      SchemaValidator.call(schema)
      form = schema.to_h.merge(fields: schema.fields.map { |f| f.to_h.merge(options: f.options.map(&:to_h), file_types: f.file_types.map(&:to_h)) })
      JSON.generate(canonical(schema_version: 1, form: form))
    end
    def self.canonical(value)
      case value
      when Hash then value.to_h { |key, item| [key, canonical(item)] }
      when Array then value.map { |item| canonical(item) }
      when BigDecimal then value.to_s("F")
      when Time, ActiveSupport::TimeWithZone then value.getutc.iso8601(6)
      when Date then value.iso8601
      else value
      end
    end
    def self.load(document)
      raise ArgumentError, "定義が大きすぎます" unless document.is_a?(String) && document.bytesize <= LIMIT
      data = JSON.parse(document, max_nesting: 8)
      check_hash(data, %w[schema_version form])
      raise ArgumentError, "未対応のschema versionです" unless data["schema_version"].is_a?(Integer) && data["schema_version"] == 1
      form = data.fetch("form")
      check_hash(form, FormSchema::DEFAULTS.keys.map(&:to_s))
      fields = form.fetch("fields")
      raise ArgumentError, "項目数が不正です" unless fields.is_a?(Array) && fields.size <= 200
      check_strings(data)
      option_count = 0
      converted = fields.map do |attributes|
        check_hash(attributes, FieldSpec::DEFAULTS.keys.map(&:to_s))
        options = attributes.fetch("options", [])
        types = attributes.fetch("file_types", [])
        constraints = attributes.fetch("constraints", {})
        raise ArgumentError, "項目の形式が不正です" unless options.is_a?(Array) && types.is_a?(Array) && constraints.is_a?(Hash)
        option_count += options.size
        raise ArgumentError, "選択肢が多すぎます" if option_count > 2000
        constraints = constraints.transform_values { |v| v }
        constraints.each do |key, value|
          next if value.nil?
          constraints[key] = case key
          when /_numeric\z/ then BigDecimal(value.to_s, exception: true)
          when /_datetime\z/ then Time.iso8601(value).utc
          when /_date\z/ then Date.iso8601(value)
          else value
          end
        end
        FieldSpec.new(**attributes.symbolize_keys.merge(constraints: constraints,
          options: options.map { |o| check_hash(o, OptionSpec::DEFAULTS.keys.map(&:to_s)); OptionSpec.new(**o.symbolize_keys) },
          file_types: types.map { |t| check_hash(t, FileTypeSpec::DEFAULTS.keys.map(&:to_s)); FileTypeSpec.new(**t.symbolize_keys) }))
      end
      SchemaValidator.call(FormSchema.new(**form.symbolize_keys.merge(fields: converted)))
    rescue JSON::ParserError, KeyError, TypeError, NoMethodError => error
      raise ArgumentError, "定義の形式が不正です: #{error.message}"
    end
    def self.check_hash(value, keys)
      raise ArgumentError, "未対応の定義属性です" unless value.is_a?(Hash) && (value.keys - keys).empty?
    end
    def self.check_strings(value)
      case value
      when String then raise ArgumentError, "文字列が大きすぎます" if value.bytesize > 100_000 || value.include?("\0")
      when Hash then value.each { |key, item| check_strings(key); check_strings(item) }
      when Array then value.each { |item| check_strings(item) }
      end
    end
    private_class_method :check_hash, :check_strings, :canonical
  end
end
