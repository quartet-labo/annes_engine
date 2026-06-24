module AnneAdmin
  module ApplicationHelper
    def anne_admin_site_name
      AnneAdmin.configuration.site_name
    end

    def anne_admin_resources
      AnneAdmin.configuration.resources.to_a
    end

    def anne_admin_dashboard_path
      return anne_admin.root_path if respond_to?(:anne_admin)

      root_path
    end

    def anne_admin_resource_index_path(resource, options = {})
      return controller.send(:anne_admin_resource_index_path, resource, options) if controller.respond_to?(:anne_admin_resource_index_path, true)
      return anne_admin.resource_index_path(resource.route_key, options) if respond_to?(:anne_admin)

      resource_index_path(resource.route_key, options)
    end

    def anne_admin_new_resource_path(resource)
      return controller.send(:anne_admin_new_resource_path, resource) if controller.respond_to?(:anne_admin_new_resource_path, true)
      return anne_admin.new_resource_path(resource.route_key) if respond_to?(:anne_admin)

      new_resource_path(resource.route_key)
    end

    def anne_admin_resource_record_path(resource, record)
      return controller.send(:anne_admin_resource_record_path, resource, record) if controller.respond_to?(:anne_admin_resource_record_path, true)
      return anne_admin.resource_record_path(resource.route_key, record) if respond_to?(:anne_admin)

      resource_record_path(resource.route_key, record)
    end

    def anne_admin_edit_resource_record_path(resource, record)
      return controller.send(:anne_admin_edit_resource_record_path, resource, record) if controller.respond_to?(:anne_admin_edit_resource_record_path, true)
      return anne_admin.edit_resource_record_path(resource.route_key, record) if respond_to?(:anne_admin)

      edit_resource_record_path(resource.route_key, record)
    end

    def anne_admin_resource_member_action_path(resource, record, action)
      return controller.send(:anne_admin_resource_member_action_path, resource, record, action) if controller.respond_to?(:anne_admin_resource_member_action_path, true)
      return anne_admin.resource_member_action_path(resource.route_key, record, action.name) if respond_to?(:anne_admin)

      resource_member_action_path(resource.route_key, record, action.name)
    end
  end
end
