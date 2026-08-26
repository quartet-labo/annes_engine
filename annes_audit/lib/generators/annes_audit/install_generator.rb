require "rails/generators"
require "rails/generators/active_record/migration"

module AnnesAudit
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
        destination = File.join(destination_root, "config/initializers/annes_audit.rb")

        if File.exist?(destination) || legacy_initializer_exists?
          say_status :skip, "config/initializers/annes_audit.rb", :yellow
        else
          template "initializer.rb", "config/initializers/annes_audit.rb"
        end
      end

      def copy_migrations
        Dir.glob(File.expand_path("../../../db/migrate/*.rb", __dir__)).sort.each do |migration|
          migration_name = annes_audit_migration_file_name(migration)

          if annes_audit_migration_exists?(migration_name)
            say_status :skip, "db/migrate/*_#{migration_name}.rb", :yellow
          else
            migration_template migration, "db/migrate/#{migration_name}"
          end
        end
      end

      private
        def annes_audit_migration_file_name(path)
          File.basename(path).sub(/\A\d+_/, "")
        end

        def annes_audit_migration_exists?(migration_name)
          Dir.glob(File.join(destination_root, "db/migrate/*_#{migration_name}")).any?
        end

        def legacy_initializer_exists?
          File.exist?(File.join(destination_root, "config/initializers/anne_audit.rb"))
        end
    end
  end
end
