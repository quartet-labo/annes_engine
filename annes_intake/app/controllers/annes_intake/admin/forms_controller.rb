module AnnesIntake
  module Admin
    class FormsController < ActionController::Base
      protect_from_forgery with: :exception
      include AdminAccess
      include ScopedDefinitionAccess
      include DefinitionErrors

      def index
        @forms = @definition_policy.scope(Form.all).order(:id)
      end

      def new
        @form = Form.new
      end

      def create
        @form = Form.new(params.require(:form).permit(:key, :name))
        Form.transaction do
          @form.save!
          @form.versions.create!(number: 1, title: @form.name)
        end
        redirect_to admin_form_path(@form), status: :see_other
      rescue ActiveRecord::RecordInvalid
        render :new, status: :unprocessable_entity
      end

      def draft
        form = definition_record(@definition_policy.scope(Form.all).find(params[:id]))
        version = nil
        form.with_lock do
          raise Definitions::Error, "既存の公開版を複製してください。" if form.versions.exists?
          version = form.versions.create!(number: 1, title: form.name)
        end
        redirect_to admin_version_path(version), status: :see_other
      end

      def show
        @form = definition_record(@definition_policy.scope(Form.all).find(params[:id]))
      end

      def update
        @form = definition_record(@definition_policy.scope(Form.all).find(params[:id]))
        DefinitionPolicy.lock(@form, context: @definition_context) do
        @form.with_lock do
          expected = Integer(params[:lock_version], exception: false)
          raise ActiveRecord::StaleObjectError.new(@form, "update") unless expected == @form.lock_version
          @form.update!(params.require(:form).permit(:name, :enabled))
        end
        end
        redirect_to admin_form_path(@form), status: :see_other
      rescue ActiveRecord::RecordInvalid
        render :show, status: :unprocessable_entity
      end
    end
  end
end
