module AnnesAdmin
  module Fields
    class AssociationField < Base
      def format(record)
        associated = read(record)
        return "-" if associated.blank?

        if options[:label_method] && associated.respond_to?(options[:label_method])
          associated.public_send(options[:label_method])
        elsif associated.respond_to?(:display_name)
          associated.display_name
        elsif associated.respond_to?(:name)
          associated.name
        else
          associated.to_s
        end
      end

      def input_type
        :select
      end
    end
  end
end
