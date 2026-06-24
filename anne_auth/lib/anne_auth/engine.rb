module AnneAuth
  class Engine < ::Rails::Engine
    isolate_namespace AnneAuth

    initializer "anne_auth.view_paths" do
      ActiveSupport.on_load(:action_controller_base) do
        append_view_path Engine.root.join("app/views")
      end
    end
  end
end
