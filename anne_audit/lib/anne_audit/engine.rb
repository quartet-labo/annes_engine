module AnneAudit
  class Engine < ::Rails::Engine
    isolate_namespace AnneAudit

    initializer "anne_audit.subscribe_notifications", after: :load_config_initializers do
      config.after_initialize do
        AnneAudit.configuration.notification_subscribers.subscribe_all!
      end
    end
  end
end
