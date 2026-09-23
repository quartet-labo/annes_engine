module AnnesInquiry
  class Engine < ::Rails::Engine
    isolate_namespace AnnesInquiry
    paths["app/views"] << AnnesFormKit::Renderer::VIEW_PATH
  end
end
