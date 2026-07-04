require "active_support/core_ext/object/blank"
require "anne_admin/resource_registry"

module AnneAdmin
  class Configuration
    attr_accessor :site_name, :default_per_page, :max_per_page
    attr_reader :resources

    def initialize
      @site_name = "Admin"
      @default_per_page = 25
      @max_per_page = 100
      @resources = ResourceRegistry.new
      @resource_paths = []
      @authentication_block = nil
      @current_user_block = nil
      @authorization_block = nil
      @current_resource_source = :manual
    end

    def resource(name, model:, **options, &block)
      resources.register(name, model:, source: current_resource_source, **options, &block)
    end

    def resource_paths
      @resource_paths
    end

    def load_resources!
      ResourceLoader.new(self).load
    end

    def default_resource_paths
      return [] unless defined?(Rails) && Rails.respond_to?(:root) && Rails.root

      [
        Rails.root.join("app/admin/resources"),
        Rails.root.join("config/anne_admin/resources")
      ]
    end

    def with_resource_source(source)
      previous_source = @current_resource_source
      @current_resource_source = source.to_sym
      yield
    ensure
      @current_resource_source = previous_source
    end

    def authenticate_with(&block)
      @authentication_block = AuthenticationAdapter.new(block) if block
      @authentication_block&.block
    end

    def current_user(&block)
      @current_user_block = block if block
      @current_user_block
    end

    def authorize_with(&block)
      @authorization_block = AuthorizationAdapter.new(block) if block
      @authorization_block&.block
    end

    def authenticate!(controller)
      raise ConfigurationError, "AnneAdmin.authenticate_with must be configured" unless authentication_block

      authentication_block.authenticate(controller)
    end

    def current_user_for(controller)
      current_user_block&.call(controller)
    end

    def authorized?(context)
      return true unless authorization_block

      authorization_block.authorized?(context)
    end

    private
      attr_reader :authentication_block, :current_user_block, :authorization_block, :current_resource_source
  end
end
