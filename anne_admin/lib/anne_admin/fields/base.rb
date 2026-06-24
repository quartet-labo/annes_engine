module AnneAdmin
  module Fields
    class Base
      TYPES = {
        string: "AnneAdmin::Fields::StringField",
        text: "AnneAdmin::Fields::TextField",
        integer: "AnneAdmin::Fields::NumberField",
        decimal: "AnneAdmin::Fields::NumberField",
        number: "AnneAdmin::Fields::NumberField",
        boolean: "AnneAdmin::Fields::BooleanField",
        date: "AnneAdmin::Fields::DateTimeField",
        datetime: "AnneAdmin::Fields::DateTimeField",
        enum: "AnneAdmin::Fields::EnumField",
        association: "AnneAdmin::Fields::AssociationField"
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
