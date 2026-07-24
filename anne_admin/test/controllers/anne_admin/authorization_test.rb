require_relative "../../test_helper"

class AnneAdmin::AuthorizationTest < AnneAdmin::IntegrationTest
  setup do
    @user = Struct.new(:email).new("viewer@example.com")
    @authorized_actions = %i[index show new create edit update normalize_name]
    @authorization_contexts = []

    AnneAdmin.configure do |config|
      config.authenticate_with { true }
      config.current_user { @user }
      config.authorize_with do |context|
        @authorization_contexts << context
        @authorized_actions.include?(context[:action])
      end
      config.resource :customers, model: "Customer" do
        field :contact_name
        field :email
        permitted_attributes :contact_name, :email
        custom_action :normalize_name, method: :post, scope: :member, label: "Normalize" do |record:, **|
          record.update!(contact_name: record.contact_name.strip)
        end
      end
    end
  end

  test "returns forbidden when authorization hook rejects action" do
    @authorized_actions.delete(:index)

    get anne_admin.resource_index_path("customers")

    assert_response :forbidden
  end

  test "hides standard and member custom actions rejected by authorization" do
    @authorized_actions -= %i[new edit normalize_name]
    customer = customers(:anan)

    get anne_admin.resource_index_path("customers")

    assert_response :success
    assert_not_includes response.body, "新規登録"

    get anne_admin.resource_record_path("customers", customer)

    assert_response :success
    assert_not_includes response.body, "編集"
    assert_not_includes response.body, "Normalize"
  end

  test "shows standard and member custom actions allowed by authorization" do
    customer = customers(:anan)

    get anne_admin.resource_index_path("customers")

    assert_response :success
    assert_includes response.body, "新規登録"

    get anne_admin.resource_record_path("customers", customer)

    assert_response :success
    assert_includes response.body, "編集"
    assert_includes response.body, "Normalize"
    assert_select "button.anne-admin-action.anne-admin-action--secondary", text: "Normalize"
  end

  test "keeps direct access to rejected actions forbidden" do
    @authorized_actions -= %i[new edit normalize_name]
    customer = customers(:anan)

    get anne_admin.new_resource_path("customers")
    assert_response :forbidden

    get anne_admin.edit_resource_record_path("customers", customer)
    assert_response :forbidden

    post anne_admin.resource_member_action_path("customers", customer, "normalize_name")
    assert_response :forbidden
  end

  test "uses the controller authorization context for action visibility" do
    customer = customers(:anan)
    resource = AnneAdmin.configuration.resources.fetch("customers")

    get anne_admin.resource_index_path("customers")
    get anne_admin.resource_record_path("customers", customer)

    {
      index: nil,
      new: nil,
      show: customer,
      edit: customer,
      normalize_name: customer
    }.each do |action, record|
      context = @authorization_contexts.find { |candidate| candidate[:action] == action }

      assert context, "expected authorization context for #{action}"
      assert_same @user, context[:user]
      assert_same resource, context[:resource]
      if record
        assert_equal record, context[:record]
      else
        assert_nil context[:record]
      end
      assert_instance_of AnneAdmin::ResourcesController, context[:controller]
    end
  end

  test "does not let a view helper override bypass controller authorization" do
    @authorized_actions.delete(:edit)
    controller_class = Class.new(AnneAdmin::ResourcesController) do
      private
        def anne_admin_authorized?(...)
          true
        end
    end
    controller = controller_class.new
    controller.instance_variable_set(:@resource, AnneAdmin.configuration.resources.fetch("customers"))

    assert_raises AnneAdmin::NotAuthorizedError do
      controller.send(:authorize_anne_admin!, :edit, record: customers(:anan))
    end
  end
end
