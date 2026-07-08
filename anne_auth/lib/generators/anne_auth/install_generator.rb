require "rails/generators"
require "rails/generators/active_record/migration"

module AnneAuth
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)
      class_option :legacy_admin,
        type: :boolean,
        default: false,
        desc: "Generate legacy AdminUser/admin_user_id migrations instead of the default User/user_id schema"

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

      def copy_user_model
        if options[:legacy_admin] || File.exist?(File.join(destination_root, "app/models/user.rb"))
          say_status :skip, "app/models/user.rb", :yellow
        else
          template "user.rb", "app/models/user.rb"
        end
      end

      def copy_migrations
        Dir.glob(File.expand_path("../../../db/migrate/*.rb", __dir__)).sort.each do |migration|
          migration_name = anne_auth_migration_file_name(migration)
          next if skip_migration?(migration_name)

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

        def skip_migration?(migration_name)
          if options[:legacy_admin]
            default_user_migration?(migration_name)
          else
            legacy_admin_migration?(migration_name)
          end
        end

        def default_user_migration?(migration_name)
          %w[
            create_anne_auth_users.rb
            create_anne_auth_sessions.rb
          ].include?(migration_name)
        end

        def legacy_admin_migration?(migration_name)
          %w[
            create_anne_auth_admin_users.rb
            create_anne_auth_admin_sessions.rb
          ].include?(migration_name)
        end
    end
  end
end
