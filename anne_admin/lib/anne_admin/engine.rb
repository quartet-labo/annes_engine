module AnneAdmin
  class Engine < ::Rails::Engine
    isolate_namespace AnneAdmin

    initializer "anne_admin.ignore_resource_paths", before: :set_autoload_paths do |app|
      next unless defined?(Rails.autoloaders)

      [
        app.root.join("app/admin/resources"),
        app.root.join("config/anne_admin/resources")
      ].each do |path|
        Rails.autoloaders.main.ignore(path)
        Rails.autoloaders.once.ignore(path)
      end
    end

    initializer "anne_admin.load_resources" do |app|
      app.config.to_prepare do
        AnneAdmin.load_resources!
      end
    end
  end
end
