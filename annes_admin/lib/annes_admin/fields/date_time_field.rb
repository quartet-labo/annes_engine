module AnnesAdmin
  module Fields
    class DateTimeField < Base
      def format(record)
        value = read(record)
        return "-" if value.blank?

        value.respond_to?(:to_fs) ? value.to_fs(:default) : value.to_s
      end

      def input_type
        :date_field
      end
    end
  end
end
