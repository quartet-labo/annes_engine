module AnnesAdmin
  class ResourcesController < ApplicationController
    include AnnesAdmin::ResourceLookup

    helper_method :annes_admin_resource_index_path,
                  :annes_admin_new_resource_path,
                  :annes_admin_resource_record_path,
                  :annes_admin_edit_resource_record_path,
                  :annes_admin_resource_member_action_path

    before_action :set_resource
    before_action :set_record, only: %i[show edit update destroy]

    def index
      require_resource_action!(:index)
      authorize_annes_admin!(:index)

      @query = Query.new(@resource, params, relation: resource_scope)
      assign_resource_collection(@query.records)
      @total_count = resource_total_count(@query)
      render_resource_template(:index)
    end

    def show
      require_resource_action!(:show)
      authorize_annes_admin!(:show, record: @record)
      render_resource_template(:show)
    end

    def new
      require_resource_action!(:new)
      authorize_annes_admin!(:new)

      assign_resource_record(build_resource_record)
      render_resource_template(:new)
    end

    def create
      require_resource_action!(:create)
      authorize_annes_admin!(:create)

      assign_resource_record(build_resource_record(resource_params))
      if @record.save
        emit_audit(:create, @record, :success)
        redirect_to after_create_path(@record), notice: create_success_notice(@record)
      else
        emit_audit(:create, @record, :failure)
        render_resource_template(:new, status: :unprocessable_entity)
      end
    end

    def edit
      require_resource_action!(:edit)
      authorize_annes_admin!(:edit, record: @record)
      render_resource_template(:edit)
    end

    def update
      require_resource_action!(:update)
      authorize_annes_admin!(:update, record: @record)

      if @record.update(resource_params)
        emit_audit(:update, @record, :success)
        redirect_to after_update_path(@record), notice: update_success_notice(@record)
      else
        emit_audit(:update, @record, :failure)
        render_resource_template(:edit, status: :unprocessable_entity)
      end
    end

    def destroy
      require_resource_action!(:destroy)
      authorize_annes_admin!(:destroy, record: @record)

      @record.destroy!
      emit_audit(:destroy, @record, :success)
      redirect_to after_destroy_path, status: :see_other, notice: destroy_success_notice(@record)
    end

    private
      def after_create_path(record)
        annes_admin_resource_record_path(@resource, record)
      end

      def after_update_path(record)
        annes_admin_resource_record_path(@resource, record)
      end

      def after_destroy_path
        annes_admin_resource_index_path(@resource)
      end

      def create_success_notice(_record)
        "#{@resource.singular_label}を登録しました。"
      end

      def update_success_notice(_record)
        "#{@resource.singular_label}を更新しました。"
      end

      def destroy_success_notice(_record)
        "#{@resource.singular_label}を削除しました。"
      end

      def resource_total_count(query)
        query.total_count
      end

      def annes_admin_resource_index_path(resource, options = {})
        resource_index_path(resource.route_key, options)
      end

      def annes_admin_new_resource_path(resource)
        new_resource_path(resource.route_key)
      end

      def annes_admin_resource_record_path(resource, record)
        resource_record_path(resource.route_key, record)
      end

      def annes_admin_edit_resource_record_path(resource, record)
        edit_resource_record_path(resource.route_key, record)
      end

      def annes_admin_resource_member_action_path(resource, record, action)
        resource_member_action_path(resource.route_key, record, action.name)
      end

      def render_resource_template(action, **options)
        render template: resource_template(action), **options
      end

      def resource_template(action)
        "annes_admin/resources/#{action}"
      end

      def resource_params
        ResourceParams.new(@resource, params).permitted
      end

      def emit_audit(action, record, status)
        AuditEvent.emit(resource: @resource, action:, record:, user: annes_admin_current_user, status:)
      end
  end
end
