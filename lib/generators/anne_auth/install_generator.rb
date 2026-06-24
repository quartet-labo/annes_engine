require "rails/generators"
require "rails/generators/active_record/migration"

module AnneAuth
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        previous_number = @previous_migration_number || Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
        @previous_migration_number = [ current_migration_number(dirname), previous_number ].max + 1
        @previous_migration_number.to_s
      end

      def copy_initializer
        template "initializer.rb", "config/initializers/anne_auth.rb"
      end

      def copy_route_example
        template "routes.rb", "config/routes/anne_auth.rb"
      end

      def copy_migrations
        Dir.glob(File.expand_path("../../../db/migrate/*.rb", __dir__)).sort.each do |migration|
          migration_name = anne_auth_migration_file_name(migration)
          if anne_auth_migration_exists?(migration_name)
            say_status :skip, "db/migrate/*_#{migration_name}.rb", :yellow
          else
            migration_template migration, "db/migrate/#{migration_name}"
          end
        end
      end

      private
        def anne_auth_migration_file_name(path)
          File.basename(path).sub(/\A\d+_/, "")
        end

        def anne_auth_migration_exists?(migration_name)
          Dir.glob(File.join(destination_root, "db/migrate/*_#{migration_name}")).any?
        end
    end
  end
end
