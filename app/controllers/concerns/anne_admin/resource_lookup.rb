module AnneAdmin
  module ResourceLookup
    extend ActiveSupport::Concern

    private
      def set_resource
        @resource = resource_config
      end

      def set_record
        assign_resource_record(find_resource_record)
      end

      def resource_name
        params[:resource_name]
      end

      def resource_config
        AnneAdmin.configuration.resources.fetch(resource_name)
      end

      def resource_model
        resource_config.model_class
      end

      def resource_scope
        resource_config.relation
      end

      def build_resource_record(attributes = {})
        resource_model.new(attributes)
      end

      def find_resource_record
        resource_scope.find(params[:id])
      end

      def assign_resource_record(record)
        @record = record
        instance_variable_set(:"@#{resource_record_variable_name}", record)
        record
      end

      def assign_resource_collection(records)
        @records = records
        instance_variable_set(:"@#{resource_collection_variable_name}", records)
        records
      end

      def resource_record_variable_name
        (@resource || resource_config).param_key
      end

      def resource_collection_variable_name
        (@resource || resource_config).route_key
      end

      def require_resource_action!(action)
        raise ActiveRecord::RecordNotFound, "Action #{action} is not enabled for #{@resource.name}" unless @resource.action?(action)
      end
  end
end
