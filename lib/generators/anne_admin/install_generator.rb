require "rails/generators"

module AnneAdmin
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "initializer.rb", "config/initializers/anne_admin.rb"
      end

      def mount_engine
        route 'mount AnneAdmin::Engine => "/admin", as: :anne_admin'
      end
    end
  end
end
