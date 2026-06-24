require_relative "../../test_helper"

class AnneAdmin::AuthorizationTest < AnneAdmin::IntegrationTest
  setup do
    AnneAdmin.configure do |config|
      config.authenticate_with { true }
      config.authorize_with { |context| context[:action] != :index }
      config.resource :customers, model: "Customer" do
        field :email
      end
    end
  end

  test "returns forbidden when authorization hook rejects action" do
    get anne_admin.resource_index_path("customers")

    assert_response :forbidden
  end
end
