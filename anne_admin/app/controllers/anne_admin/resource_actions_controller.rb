module AnneAdmin
  class ResourceActionsController < ApplicationController
    include AnneAdmin::ResourceLookup

    before_action :set_resource
    before_action :set_action
    before_action :set_record, only: :member

    def member
      require_action_scope!(:member)
      require_action_method!
      return if performed?

      authorize_anne_admin!(@action.name, record: @record)

      @action.call(record: @record, controller: self, resource: @resource)
      AuditEvent.emit(resource: @resource, action: @action.name, record: @record, user: anne_admin_current_user, status: :success)
      redirect_to after_action_path(@record), notice: "#{@action.label}を実行しました。" unless performed?
    end

    def collection
      require_action_scope!(:collection)
      require_action_method!
      return if performed?

      authorize_anne_admin!(@action.name)

      @action.call(record: nil, controller: self, resource: @resource)
      AuditEvent.emit(resource: @resource, action: @action.name, record: nil, user: anne_admin_current_user, status: :success)
      redirect_to after_action_path, notice: "#{@action.label}を実行しました。" unless performed?
    end

    private
      def after_action_path(record = nil)
        return resource_record_path(@resource.route_key, record) if record

        resource_index_path(@resource.route_key)
      end

      def set_action
        @action = @resource.custom_actions.fetch(params[:action_name]) do
          raise ActiveRecord::RecordNotFound, "Admin action #{params[:action_name].inspect} is not registered"
        end
      end

      def require_action_scope!(scope)
        raise ActiveRecord::RecordNotFound, "Admin action #{@action.name.inspect} is not a #{scope} action" unless @action.scope == scope
      end

      def require_action_method!
        return if request.request_method_symbol == @action.method

        head :method_not_allowed
      end
  end
end
