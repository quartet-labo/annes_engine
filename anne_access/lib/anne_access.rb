require "anne_access/version"
require "anne_access/errors"
require "anne_access/configuration"
require "anne_access/action_mapper"
require "anne_access/ability"
require "anne_access/engine" if defined?(Rails::Engine)

module AnneAccess
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def ability_for(principal)
      Ability.new(principal)
    end

    def can?(principal, action, resource, record: nil)
      ability_for(principal).can?(action, resource, record:)
    end

    def authorize!(principal, action, resource, record: nil)
      return true if can?(principal, action, resource, record:)

      raise NotAuthorizedError, "not authorized to #{action} #{resource}"
    end
  end
end
