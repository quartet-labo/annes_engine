module AnnesIntake
  module Definitions
    # Private case definitions must never become shared templates.
    class ExportSchema
      def self.call(version:, context:)
        raise Flows::Forbidden if version.form.follow_up_request_id
        DefinitionPolicy.new(context: context).authorize!(version, action: :admin_view_definition)
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
