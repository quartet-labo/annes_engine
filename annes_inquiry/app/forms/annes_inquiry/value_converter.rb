module AnnesInquiry
  class ValueConverter
    INTEGER_RANGE = (-(2**63)..(2**63 - 1))
    DECIMAL_LIMIT = BigDecimal("1E19")

    def self.call(field, raw, time_zone: "UTC")
      return nil if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)
      case field.value_type
      when "text"
        value = raw
        value = value.strip if %w[trim trim_downcase].include?(field.normalizer_key)
        value = value.downcase if field.normalizer_key == "trim_downcase"
        value
      when "integer"
        raise ArgumentError unless raw.match?(/\A[+-]?\d+\z/)
        value = Integer(raw, 10)
        raise ArgumentError unless INTEGER_RANGE.cover?(value)
        value
      when "decimal"
        raise ArgumentError unless raw.match?(/\A[+-]?\d+(?:\.\d{1,6})?\z/)
        value = BigDecimal(raw)
        raise ArgumentError unless value.abs < DECIMAL_LIMIT
        value
      when "boolean"
        return true if %w[true 1].include?(raw)
        return false if %w[false 0].include?(raw)
        raise ArgumentError
      when "date"
        raise ArgumentError unless raw.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        value = Date.iso8601(raw)
        raise ArgumentError unless value.year.positive?
        value
      when "datetime"
        raise ArgumentError unless raw.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,6})?)?\z/)
        clock = raw.split("T").last.split(":")
        raise ArgumentError if clock[0].to_i > 23 || clock[1].to_i > 59 || clock.fetch(2, "0").to_f >= 60
        date = DateTime.iso8601(raw)
        raise ArgumentError unless date.year.positive?
        zone = ActiveSupport::TimeZone[time_zone] or raise ArgumentError
        local = Time.utc(date.year, date.month, date.day, date.hour, date.minute, date.second + date.sec_fraction)
        zone.tzinfo.local_to_utc(local)
      when "multiple_choice", "attachment" then Array(raw).reject { |item| item == "" }
      else raw
      end
    rescue Date::Error, TZInfo::PeriodNotFound, TZInfo::AmbiguousTime
      raise ArgumentError
    end
  end
end
