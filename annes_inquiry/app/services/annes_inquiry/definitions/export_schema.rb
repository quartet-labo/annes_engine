module AnnesInquiry
  module Definitions
    # Callers must authorize the source before invoking this non-HTTP API.
    class ExportSchema
      def self.call(version:)
        version.form.with_lock do
          version.reload
          raise Error, "公開版だけを書き出せます" unless version.published?
          AnnesFormKit::SchemaCodec.dump(SchemaAdapter.call(version))
        end
      rescue ArgumentError => error
        raise Error, error.message
      end
    end
  end
end
