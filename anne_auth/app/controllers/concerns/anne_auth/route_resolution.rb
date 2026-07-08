module AnneAuth
  module RouteResolution
    extend ActiveSupport::Concern

    included do
      helper_method :auth_route if respond_to?(:helper_method)
    end

    private
      def auth_route(name, ...)
        return public_send(name, ...) if respond_to?(name)
        return main_app.public_send(name, ...) if respond_to?(:main_app) && main_app.respond_to?(name)

        AnneAuth::Engine.routes.url_helpers.public_send(name, ...)
      end
  end
end
