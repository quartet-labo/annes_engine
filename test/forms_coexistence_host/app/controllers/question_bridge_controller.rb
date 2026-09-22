# Optional host bridge: the engines never refer to each other.
class QuestionBridgeController < ActionController::Base
  protect_from_forgery with: :exception
  before_action :authorize_copy
  def new
  end
  def create
    document = AnnesInquiry::Definitions::ExportSchema.call(version: @source)
    version = AnnesIntake::Definitions::ImportSchema.call(document: document, context: @context)
    render plain: "独立した下書きを作成しました。コピー元の変更は同期されません。 #{version.id}", status: :created
  end
  private
  def authorize_copy
    inquiry = AnnesInquiry.configuration
    admin = inquiry.admin_authenticator.call(self)
    return head :forbidden unless admin && inquiry.admin_authorizer.call(self, admin) == true
    # This example administrator owns all standalone templates. A tenant host
    # must apply its own scope to this relation before finding the source.
    @source = AnnesInquiry::FormVersion.published.find(params[:id])
    intake = AnnesIntake.configuration
    target_admin = intake.admin_authenticator.call(self)
    return head :forbidden unless target_admin && intake.admin_authorizer.call(self, target_admin) == true
    @context = intake.definition_authorizer.prepare_context(self, admin: target_admin)
    AnnesIntake::DefinitionPolicy.new(context: @context).authorize!(nil)
  end
end
