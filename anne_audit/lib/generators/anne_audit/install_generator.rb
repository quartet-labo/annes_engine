require "rails/generators"
require "rails/generators/active_record/migration"

module AnneAudit
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
        destination = File.join(destination_root, "config/initializers/anne_audit.rb")

        if File.exist?(destination)
          say_status :skip, "config/initializers/anne_audit.rb", :yellow
        else
          template "initializer.rb", "config/initializers/anne_audit.rb"
        end
      end

      def copy_migrations
        Dir.glob(File.expand_path("../../../db/migrate/*.rb", __dir__)).sort.each do |migration|
          migration_name = anne_audit_migration_file_name(migration)

          if anne_audit_migration_exists?(migration_name)
            say_status :skip, "db/migrate/*_#{migration_name}.rb", :yellow
          else
            migration_template migration, "db/migrate/#{migration_name}"
          end
        end
      end

      private
        def anne_audit_migration_file_name(path)
          File.basename(path).sub(/\A\d+_/, "")
        end

        def anne_audit_migration_exists?(migration_name)
          Dir.glob(File.join(destination_root, "db/migrate/*_#{migration_name}")).any?
        end
    end
  end
end
