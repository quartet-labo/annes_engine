require "anne_admin/version"
require "anne_admin/fields/base"
require "anne_admin/fields/string_field"
require "anne_admin/fields/text_field"
require "anne_admin/fields/number_field"
require "anne_admin/fields/boolean_field"
require "anne_admin/fields/date_time_field"
require "anne_admin/fields/enum_field"
require "anne_admin/fields/association_field"
require "anne_admin/action_config"
require "anne_admin/audit_event"
require "anne_admin/authentication_adapter"
require "anne_admin/authorization_adapter"
require "anne_admin/configuration"
require "anne_admin/configuration_error"
require "anne_admin/model_resolver"
require "anne_admin/pagination"
require "anne_admin/query"
require "anne_admin/resource_params"
require "anne_admin/resource_config"
require "anne_admin/resource_registry"
require "anne_admin/resource_loader"
require "anne_admin/search"
require "anne_admin/sort"
require "anne_admin/engine" if defined?(Rails::Engine)

module AnneAdmin
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
