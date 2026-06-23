require "rails/generators"

module AnneAuth
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "initializer.rb", "config/initializers/anne_auth.rb"
      end

      def copy_route_example
        template "routes.rb", "config/routes/anne_auth.rb"
      end

      def copy_migrations
        Dir.glob(File.expand_path("../../../db/migrate/*.rb", __dir__)).sort.each do |migration|
          copy_file migration, "db/migrate/#{File.basename(migration)}"
        end
      end
    end
  end
end
