module AnnesAdmin
  class Engine < ::Rails::Engine
    isolate_namespace AnnesAdmin

    initializer "annes_admin.assets", before: "propshaft.append_assets_path" do |app|
      next unless app.config.respond_to?(:assets)

      app.config.assets.paths << root.join("app/assets/stylesheets")
      app.config.assets.paths << root.join("app/assets/javascripts")
    end

    initializer "annes_admin.ignore_resource_paths", before: :set_autoload_paths do |app|
      next unless defined?(Rails.autoloaders)

      [
        app.root.join("app/admin/resources"),
        app.root.join("config/annes_admin/resources")
      ].each do |path|
        Rails.autoloaders.main.ignore(path)
        Rails.autoloaders.once.ignore(path)
      end
    end

    initializer "annes_admin.load_resources" do |app|
      app.config.to_prepare do
        AnnesAdmin.load_resources!
      end
    end

  end
end
