module AnnesAudit
  class Engine < ::Rails::Engine
    isolate_namespace AnnesAudit

    initializer "annes_audit.subscribe_notifications", after: :load_config_initializers do
      config.after_initialize do
        AnnesAudit.configuration.notification_subscribers.subscribe_all!
      end
    end
  end
end
