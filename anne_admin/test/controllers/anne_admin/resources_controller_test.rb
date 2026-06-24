require_relative "../../test_helper"

class AnneAdmin::ResourcesControllerTest < AnneAdmin::IntegrationTest
  setup do
    AnneAdmin.configure do |config|
      config.authenticate_with { true }
      config.resource :customers, model: "Customer" do
        label "顧客"
        field :company_name, searchable: true, sortable: true
        field :contact_name, searchable: true, sortable: true
        field :email, searchable: true, sortable: true
        field :phone
        permitted_attributes :company_name, :contact_name, :email, :phone
      end
    end
  end

  test "lists registered resource records" do
    engine_get "/customers"

    assert_engine_response :success
    assert_includes engine_response.body, customers(:anan).email
  end

  test "searches records by allowlisted fields" do
    engine_get "/customers", params: { q: customers(:anan).contact_name }

    assert_engine_response :success
    assert_includes engine_response.body, customers(:anan).email
  end

  test "shows a record" do
    engine_get "/customers/#{customers(:anan).id}"

    assert_engine_response :success
    assert_includes engine_response.body, customers(:anan).email
  end

  test "creates a record with permitted attributes" do
    assert_difference "Customer.count", 1 do
      engine_post "/customers", params: {
        customer: {
          company_name: "新規会社",
          contact_name: "新規 太郎",
          email: "new-admin-resource@example.com",
          phone: "03-0000-0000",
          memo: "ignored"
        }
      }
    end

    customer = Customer.order(:created_at).last
    assert_engine_redirected_to "/admin/customers/#{customer.id}"
    assert_nil customer.memo
  end

  test "renders validation errors" do
    assert_no_difference "Customer.count" do
      engine_post "/customers", params: {
        customer: { contact_name: "", email: "invalid" }
      }
    end

    assert_engine_response :unprocessable_entity
    assert_includes engine_response.body, "入力内容を確認してください"
  end

  test "updates a record with permitted attributes" do
    engine_patch "/customers/#{customers(:anan).id}", params: {
      customer: {
        contact_name: "更新 太郎",
        memo: "ignored"
      }
    }

    assert_engine_redirected_to "/admin/customers/#{customers(:anan).id}"
    assert_equal "更新 太郎", customers(:anan).reload.contact_name
    assert_not_equal "ignored", customers(:anan).memo
  end

  test "rejects unknown resources" do
    assert_raises(ActiveRecord::RecordNotFound) do
      engine_get "/missing"
    end
  end

  test "assigns resource-specific record variable" do
    controller = AnneAdmin::ResourcesController.new
    controller.instance_variable_set(:@resource, AnneAdmin.configuration.resources.fetch("customers"))

    controller.send(:assign_resource_record, customers(:anan))

    assert_equal customers(:anan), controller.instance_variable_get(:@record)
    assert_equal customers(:anan), controller.instance_variable_get(:@customer)
  end

  test "assigns resource-specific collection variable" do
    controller = AnneAdmin::ResourcesController.new
    controller.instance_variable_set(:@resource, AnneAdmin.configuration.resources.fetch("customers"))
    records = Customer.where(id: customers(:anan).id)

    controller.send(:assign_resource_collection, records)

    assert_equal records, controller.instance_variable_get(:@records)
    assert_equal records, controller.instance_variable_get(:@customers)
  end

  test "allows host controllers to override resource variable names" do
    controller_class = Class.new(AnneAdmin::ResourcesController) do
      private
        def resource_record_variable_name
          "legacy_customer"
        end

        def resource_collection_variable_name
          "legacy_customers"
        end
    end
    controller = controller_class.new
    controller.instance_variable_set(:@resource, AnneAdmin.configuration.resources.fetch("customers"))
    records = Customer.where(id: customers(:anan).id)

    controller.send(:assign_resource_record, customers(:anan))
    controller.send(:assign_resource_collection, records)

    assert_equal customers(:anan), controller.instance_variable_get(:@legacy_customer)
    assert_equal records, controller.instance_variable_get(:@legacy_customers)
  end

  private
    def engine_session
      @engine_session ||= ActionDispatch::Integration::Session.new(AnneAdmin::Engine)
    end

    def engine_get(...)
      engine_session.get(...)
    end

    def engine_post(...)
      engine_session.post(...)
    end

    def engine_patch(...)
      engine_session.patch(...)
    end

    def engine_response
      engine_session.response
    end

    def assert_engine_response(status)
      assert_equal engine_status_code(status), engine_response.status, engine_response.body
    end

    def assert_engine_redirected_to(path)
      assert_includes 300...400, engine_response.status
      assert_equal path, URI.parse(engine_response.headers.fetch("Location")).path
    end

    def engine_status_code(status)
      {
        success: 200,
        not_found: 404,
        unprocessable_entity: 422
      }.fetch(status) { Rack::Utils.status_code(status) }
    end
end
