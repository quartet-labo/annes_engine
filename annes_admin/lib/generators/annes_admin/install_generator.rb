require "rails/generators"

module AnnesAdmin
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        return if legacy_initializer_exists?

        template "initializer.rb", "config/initializers/annes_admin.rb"
      end

      def copy_resource_example
        template "resources/users.rb", "app/admin/resources/users.rb"
      end

      def mount_engine
        return if route_mounted?

        route 'mount AnnesAdmin::Engine => "/admin", as: :annes_admin'
      end

      private
        def route_mounted?
          routes_path = File.join(destination_root, "config/routes.rb")
          File.exist?(routes_path) && File.read(routes_path).include?("mount AnnesAdmin::Engine")
        end

        def legacy_initializer_exists?
          File.exist?(File.join(destination_root, "config/initializers/anne_admin.rb"))
        end
    end
  end
end
