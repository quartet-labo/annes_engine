module AnnesAdmin
  module ApplicationHelper
    def annes_admin_site_name
      AnnesAdmin.configuration.site_name
    end

    def annes_admin_resources
      AnnesAdmin.configuration.resources.to_a
    end

    def annes_admin_dashboard_path
      return annes_admin.root_path if respond_to?(:annes_admin)

      root_path
    end

    def annes_admin_resource_index_path(resource, options = {})
      return controller.send(:annes_admin_resource_index_path, resource, options) if controller.respond_to?(:annes_admin_resource_index_path, true)
      return annes_admin.resource_index_path(resource.route_key, options) if respond_to?(:annes_admin)

      resource_index_path(resource.route_key, options)
    end

    def annes_admin_new_resource_path(resource)
      return controller.send(:annes_admin_new_resource_path, resource) if controller.respond_to?(:annes_admin_new_resource_path, true)
      return annes_admin.new_resource_path(resource.route_key) if respond_to?(:annes_admin)

      new_resource_path(resource.route_key)
    end

    def annes_admin_resource_record_path(resource, record)
      return controller.send(:annes_admin_resource_record_path, resource, record) if controller.respond_to?(:annes_admin_resource_record_path, true)
      return annes_admin.resource_record_path(resource.route_key, record) if respond_to?(:annes_admin)

      resource_record_path(resource.route_key, record)
    end

    def annes_admin_edit_resource_record_path(resource, record)
      return controller.send(:annes_admin_edit_resource_record_path, resource, record) if controller.respond_to?(:annes_admin_edit_resource_record_path, true)
      return annes_admin.edit_resource_record_path(resource.route_key, record) if respond_to?(:annes_admin)

      edit_resource_record_path(resource.route_key, record)
    end

    def annes_admin_resource_member_action_path(resource, record, action)
      return controller.send(:annes_admin_resource_member_action_path, resource, record, action) if controller.respond_to?(:annes_admin_resource_member_action_path, true)
      return annes_admin.resource_member_action_path(resource.route_key, record, action.name) if respond_to?(:annes_admin)

      resource_member_action_path(resource.route_key, record, action.name)
    end
  end
end
