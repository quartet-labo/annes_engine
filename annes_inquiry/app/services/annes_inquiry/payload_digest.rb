module AnnesInquiry
  class PayloadDigest
    def self.call(values, identity:, context:)
      Digest::SHA256.hexdigest(JSON.generate(canonical([ identity, context, values ])))
    end

    def self.canonical(value)
      case value
      when Hash then value.keys.sort_by(&:to_s).to_h { |key| [ key.to_s, canonical(value[key]) ] }
      when Array then value.map { |item| canonical(item) }
      when BigDecimal then value.to_s("F")
      when Time, ActiveSupport::TimeWithZone then value.utc.iso8601(6)
      when Date then value.iso8601
      when AttachmentValidator::Upload then [ value.checksum, value.byte_size, value.filename, value.content_type ]
      when String, Integer, TrueClass, FalseClass, NilClass then value
      else raise ArgumentError, "Unsupported digest context type: #{value.class}"
      end
    end
    private_class_method :canonical
  end
end
