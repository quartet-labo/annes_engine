require "annes_access/version"
require "annes_access/errors"
require "annes_access/configuration"
require "annes_access/action_mapper"
require "annes_access/ability"
require "annes_access/engine" if defined?(Rails::Engine)

module AnnesAccess
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
