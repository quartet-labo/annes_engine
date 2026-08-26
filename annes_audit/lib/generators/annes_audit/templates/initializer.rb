AnnesAudit.configure do |config|
  # Default: keep the emitting request decoupled from audit persistence. When
  # set to true, notification subscribers re-raise persistence errors so the
  # originating request or operation fails.
  config.raise_on_persistence_error = false

  # Add host-specific sensitive metadata keys here. Keys are matched
  # case-insensitively and recursively before metadata is stored.
  # config.metadata_filter_keys += %i[api_key customer_secret]

  # Register notification mappers for event streams the host wants to persist.
  # AnnesAudit core stays generic; each mapper owns one notification contract.
  #
  # config.notification_subscribers.register(
  #   "annes_admin.audit",
  #   mapper: AnnesAudit::Mappers::AnnesAdmin
  # )
  #
  # config.notification_subscribers.register(
  #   "annes_auth.account_event",
  #   mapper: AnnesAudit::Mappers::AnnesAuth
  # )
end
