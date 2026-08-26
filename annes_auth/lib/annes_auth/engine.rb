module AnnesAuth
  class Engine < ::Rails::Engine
    isolate_namespace AnnesAuth

    initializer "annes_auth.view_paths" do
      ActiveSupport.on_load(:action_controller_base) do
        append_view_path Engine.root.join("app/views")
      end
    end

    initializer "annes_auth.filter_parameters" do |app|
      app.config.filter_parameters += [ :token ] unless app.config.filter_parameters.include?(:token)
    end
  end
end
