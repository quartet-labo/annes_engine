module AnneAdmin
  module Fields
    class BooleanField < Base
      def format(record)
        read(record) ? "Yes" : "No"
      end

      def input_type
        :check_box
      end
    end
  end
end
