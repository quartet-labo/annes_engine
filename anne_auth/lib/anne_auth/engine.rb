module AnneAuth
  class Engine < ::Rails::Engine
    isolate_namespace AnneAuth

    initializer "anne_auth.view_paths" do
      ActiveSupport.on_load(:action_controller_base) do
        append_view_path Engine.root.join("app/views")
      end
    end

    initializer "anne_auth.filter_parameters" do |app|
      app.config.filter_parameters += [ :token ] unless app.config.filter_parameters.include?(:token)
    end
  end
end
