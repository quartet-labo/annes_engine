module AnnesIntake
  class Engine < ::Rails::Engine
    isolate_namespace AnnesIntake
    paths["app/views"] << AnnesFormKit::Renderer::VIEW_PATH
  end
end
