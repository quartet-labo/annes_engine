module AnnesInquiry
  class ValueConverter
    INTEGER_RANGE = AnnesFormKit::ValueConverter::INTEGER_RANGE
    DECIMAL_LIMIT = AnnesFormKit::ValueConverter::DECIMAL_LIMIT
    def self.call(field, raw, time_zone: "UTC")
      AnnesFormKit::ValueConverter.call(field: Definitions::SchemaAdapter.field(field), raw: raw, time_zone: time_zone)
    end
  end
end
