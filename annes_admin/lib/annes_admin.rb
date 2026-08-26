require "annes_admin/version"
require "annes_admin/fields/base"
require "annes_admin/fields/string_field"
require "annes_admin/fields/text_field"
require "annes_admin/fields/number_field"
require "annes_admin/fields/boolean_field"
require "annes_admin/fields/date_time_field"
require "annes_admin/fields/enum_field"
require "annes_admin/fields/association_field"
require "annes_admin/action_config"
require "annes_admin/audit_event"
require "annes_admin/authentication_adapter"
require "annes_admin/authorization_adapter"
require "annes_admin/configuration"
require "annes_admin/configuration_error"
require "annes_admin/model_resolver"
require "annes_admin/pagination"
require "annes_admin/query"
require "annes_admin/resource_params"
require "annes_admin/resource_config"
require "annes_admin/resource_registry"
require "annes_admin/resource_loader"
require "annes_admin/search"
require "annes_admin/sort"
require "annes_admin/engine" if defined?(Rails::Engine)

module AnnesAdmin
  class NotAuthorizedError < StandardError
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def resource(name, model:, **options, &block)
      configuration.resource(name, model:, **options, &block)
    end

    def load_resources!
      configuration.load_resources!
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
