module AnneAdmin
  module Fields
    class EnumField < Base
      def format(record)
        value = read(record)
        collection_hash.fetch(value.to_s, value.presence || "-")
      end

      def input_type
        :select
      end

      def collection_hash
        values = collection.respond_to?(:call) ? collection.call : collection
        values || {}
      end
    end
  end
end
