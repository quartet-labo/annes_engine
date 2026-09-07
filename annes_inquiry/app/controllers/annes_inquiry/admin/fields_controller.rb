module AnnesInquiry
  module Admin
    class FieldsController < ActionController::Base
      protect_from_forgery with: :exception
      include AdminAccess
      include DefinitionErrors
      before_action :load_definition

      def new
        type = TypeRegistry::WIDGETS.key?(params[:value_type]) ? params[:value_type] : "text"
        @field = @version.fields.new(value_type: type, widget: TypeRegistry::WIDGETS.fetch(type).first)
      end

      def create
        edit_draft do |draft|
          @field = draft.fields.new(field_attributes)
          @field.save!
        end
        redirect_to edit_admin_field_path(@field), status: :see_other
      rescue ActiveRecord::RecordInvalid
        render :new, status: :unprocessable_entity
      end

      def edit
      end

      def update
        edit_draft do |draft|
          @field = draft.fields.find(@field.id)
          attributes = field_attributes
          if attributes[:value_type] && attributes[:value_type] != @field.value_type
            clear_inapplicable_settings(attributes[:value_type])
            inapplicable = TypeRegistry::SETTINGS.values.flatten.uniq - TypeRegistry::SETTINGS.fetch(attributes[:value_type], [])
            attributes = attributes.except(*inapplicable)
            attributes = attributes.except(:must_be_true) unless attributes[:value_type] == "boolean"
          end
          @field.update!(attributes)
        end
        redirect_to edit_admin_field_path(@field), status: :see_other
      rescue ActiveRecord::RecordInvalid
        render :edit, status: :unprocessable_entity
      end

      def destroy
        edit_draft { |draft| draft.fields.find(@field.id).destroy! }
        redirect_to admin_version_path(@version), status: :see_other
      end

      def add_option
        change_child(:options, :option, %i[value label position])
      end

      def update_option
        change_child(:options, :option, %i[value label position], id: params[:child_id])
      end

      def remove_option
        change_child(:options, :option, [], id: params[:child_id], destroy: true)
      end

      def add_file_type
        change_child(:file_types, :file_type, %i[extension content_type])
      end

      def update_file_type
        change_child(:file_types, :file_type, %i[extension content_type], id: params[:child_id])
      end

      def remove_file_type
        change_child(:file_types, :file_type, [], id: params[:child_id], destroy: true)
      end

      private
        def load_definition
          if params[:version_id]
            @version = FormVersion.find(params[:version_id])
          else
            @field = Field.find(params[:id])
            @version = @field.form_version
          end
        end

        def field_attributes
          params.require(:field).permit(:key, :label, :value_type, :widget, :placeholder, :help_text, :required,
            :position, :must_be_true, *TypeRegistry::SETTINGS.values.flatten.uniq)
        end

        def edit_draft(&block)
          Definitions::DraftEditor.call(@version, expected_lock_version: params[:lock_version], &block)
          @version.reload
        end

        def clear_inapplicable_settings(type)
          allowed = TypeRegistry::SETTINGS.fetch(type, [])
          (TypeRegistry::SETTINGS.values.flatten.uniq - allowed).each { |key| @field[key] = nil }
          @field.must_be_true = false unless type == "boolean"
          @field.options.destroy_all unless %w[single_choice multiple_choice].include?(type)
          @field.file_types.destroy_all unless type == "attachment"
        end

        def change_child(collection, param_key, permitted, id: nil, destroy: false)
          edit_draft do |draft|
            @field = draft.fields.find(@field.id)
            association = @field.public_send(collection)
            child = id ? association.find(id) : association.new
            instance_variable_set("@edited_#{param_key}", child)
            destroy ? child.destroy! : child.update!(params.require(param_key).permit(*permitted))
          end
          redirect_to edit_admin_field_path(@field), status: :see_other
        rescue ActiveRecord::RecordInvalid
          render :edit, status: :unprocessable_entity
        end
    end
  end
end
