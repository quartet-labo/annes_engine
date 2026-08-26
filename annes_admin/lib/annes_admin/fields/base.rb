module AnnesAdmin
  module Fields
    class Base
      TYPES = {
        string: "AnnesAdmin::Fields::StringField",
        text: "AnnesAdmin::Fields::TextField",
        integer: "AnnesAdmin::Fields::NumberField",
        decimal: "AnnesAdmin::Fields::NumberField",
        number: "AnnesAdmin::Fields::NumberField",
        boolean: "AnnesAdmin::Fields::BooleanField",
        date: "AnnesAdmin::Fields::DateTimeField",
        datetime: "AnnesAdmin::Fields::DateTimeField",
        enum: "AnnesAdmin::Fields::EnumField",
        association: "AnnesAdmin::Fields::AssociationField"
      }.freeze

      attr_reader :name, :label, :options

      def self.build(name, type:, **options)
        field_class = TYPES.fetch(type.to_sym) do
          raise ConfigurationError, "Unknown admin field type #{type.inspect}"
        end.constantize
        field_class.new(name, **options)
      end

      def initialize(name, label: nil, searchable: false, sortable: false, permitted: true, readonly: false, **options)
        @name = name.to_sym
        @label = label
        @searchable = searchable
        @sortable = sortable
        @permitted = permitted
        @readonly = readonly
        @options = options
      end

      def label_text
        label.presence || name.to_s.humanize
      end

      def searchable?
        @searchable
      end

      def sortable?
        @sortable
      end

      def permitted?
        @permitted && !readonly?
      end

      def readonly?
        @readonly
      end

      def read(record)
        if options[:display_with]
          options[:display_with].call(record)
        elsif record.respond_to?(name)
          record.public_send(name)
        end
      end

      def format(record)
        read(record).presence || "-"
      end

      def input_type
        :text_field
      end

      def collection
        options[:collection]
      end
    end
  end
end
