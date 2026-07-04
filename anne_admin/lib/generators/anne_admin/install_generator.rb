require "rails/generators"

module AnneAdmin
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "initializer.rb", "config/initializers/anne_admin.rb"
      end

      def copy_resource_example
        template "resources/users.rb", "app/admin/resources/users.rb"
      end

      def mount_engine
        return if route_mounted?

        route 'mount AnneAdmin::Engine => "/admin", as: :anne_admin'
      end

      private
        def route_mounted?
          routes_path = File.join(destination_root, "config/routes.rb")
          File.exist?(routes_path) && File.read(routes_path).include?("mount AnneAdmin::Engine")
        end
    end
  end
end
