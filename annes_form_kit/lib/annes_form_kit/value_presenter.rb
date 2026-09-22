module AnnesFormKit
  class ValuePresenter
    def self.call(field:, value:, time_zone: "UTC")
      return "未回答" if value.nil? || value == "" || value == []
      if field.choice?
        selected = Array(value).reject { |item| item == "" }
        return "未回答" if selected.empty?
        return field.options.select { |option| selected.include?(option.value) }.map(&:label).join("、")
      end
      case value
      when true then "はい"
      when false then "いいえ"
      when Time, ActiveSupport::TimeWithZone then "#{value.in_time_zone(time_zone).strftime('%Y-%m-%d %H:%M:%S')} (#{time_zone})"
      when BigDecimal then value.to_s("F")
      when Array then value.map { |item| item.respond_to?(:filename) ? item.filename.to_s : item.to_s }.join("、")
      else String.new(value.to_s)
      end
    end
  end
end
