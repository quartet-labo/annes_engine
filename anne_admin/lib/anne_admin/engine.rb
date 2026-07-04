module AnneAdmin
  class Engine < ::Rails::Engine
    isolate_namespace AnneAdmin

    initializer "anne_admin.load_resources" do |app|
      app.config.to_prepare do
        AnneAdmin.load_resources!
      end
    end
  end
end
