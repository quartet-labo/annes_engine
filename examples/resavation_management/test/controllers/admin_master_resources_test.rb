require "test_helper"

class AdminMasterResourcesTest < ActionDispatch::IntegrationTest
  setup do
    @customer = Customer.create!(
      name: "Zulu Customer",
      name_kana: "ズールー カスタマー",
      email: "taro@example.com",
      phone: "03-1234-5678",
      memo: "既存顧客"
    )
    @other_customer = Customer.create!(name: "Alpha Customer", name_kana: "アルファ カスタマー")
    @resource = ReservationResource.create!(name: "会議室A", kind: "room", capacity: 8, memo: "3階")
    @other_resource = ReservationResource.create!(name: "プロジェクター", kind: "equipment", capacity: 1)
  end

  test "master resources define fields, search, sorting, permitted attributes, and actions" do
    assert_equal %w[customers reservation_resources], AnneAdmin.configuration.resources.map(&:name)

    customers = AnneAdmin.configuration.resources.fetch(:customers)
    assert_equal "顧客", customers.label
    assert_equal %i[customer_number name name_kana email phone active memo created_at], customers.fields.map(&:name)
    assert_equal %i[name name_kana email phone active memo], customers.permitted_attributes
    assert_equal %i[customer_number name name_kana email phone], customers.searchable_attributes.to_a
    assert_equal %i[customer_number name name_kana email active created_at], customers.sortable_attributes.to_a
    assert_master_actions(customers)

    resources = AnneAdmin.configuration.resources.fetch(:reservation_resources)
    assert_equal "予約対象", resources.label
    assert_equal %i[name kind capacity active memo created_at], resources.fields.map(&:name)
    assert_equal %i[name kind capacity active memo], resources.permitted_attributes
    assert_equal %i[name memo], resources.searchable_attributes.to_a
    assert_equal %i[name kind capacity active created_at], resources.sortable_attributes.to_a
    assert_master_actions(resources)
  end

  test "admin manages customer and reservation resource records" do
    sign_in_as_role(:admin)

    get "/admin/customers", params: { q: "Zulu" }
    assert_response :success
    assert_includes response.body, @customer.name
    assert_not_includes response.body, @other_customer.name

    get "/admin/customers", params: { sort: "name", direction: "desc" }
    assert_response :success
    assert_operator response.body.index(@customer.name), :<, response.body.index(@other_customer.name)

    assert_difference("Customer.count") do
      post "/admin/customers", params: {
        customer: {
          customer_number: "C-MANUAL",
          name: "佐藤 次郎",
          name_kana: "サトウ ジロウ",
          email: "jiro@example.com",
          phone: "03-9999-0000",
          active: "1",
          memo: "電話受付"
        }
      }
    end
    created_customer = Customer.order(:created_at).last
    assert_match(/\AC-[0-9A-F]{8}\z/, created_customer.customer_number)
    assert_not_equal "C-MANUAL", created_customer.customer_number

    patch "/admin/customers/#{@customer.id}", params: { customer: { name: "山田 太郎（更新）", active: "0" } }
    assert_redirected_to "/admin/customers/#{@customer.id}"
    assert_equal [ "山田 太郎（更新）", false ], @customer.reload.values_at(:name, :active)

    get "/admin/reservation_resources", params: { q: "会議室" }
    assert_response :success
    assert_includes response.body, @resource.name
    assert_not_includes response.body, @other_resource.name

    assert_difference("ReservationResource.count") do
      post "/admin/reservation_resources", params: {
        reservation_resource: { name: "応接室", kind: "room", capacity: 4, active: "1", memo: "1階" }
      }
    end

    patch "/admin/reservation_resources/#{@resource.id}", params: {
      reservation_resource: { capacity: 10, active: "0" }
    }
    assert_redirected_to "/admin/reservation_resources/#{@resource.id}"
    assert_equal [ 10, false ], @resource.reload.values_at(:capacity, :active)
  end

  test "operator manages customers but can only read reservation resources" do
    sign_in_as_role(:operator)

    assert_readable("customers", @customer)
    assert_response_allowed(:get, "/admin/customers/new")
    assert_response_allowed(:post, "/admin/customers", customer: { name: "担当者登録" })
    assert_response_allowed(:get, "/admin/customers/#{@customer.id}/edit")
    assert_response_allowed(:patch, "/admin/customers/#{@customer.id}", customer: { memo: "担当者更新" })

    assert_readable("reservation_resources", @resource)
    assert_response_forbidden(:get, "/admin/reservation_resources/new")
    assert_no_difference("ReservationResource.count") do
      assert_response_forbidden(:post, "/admin/reservation_resources", reservation_resource: { name: "不可", kind: "room", capacity: 1 })
    end
    assert_response_forbidden(:get, "/admin/reservation_resources/#{@resource.id}/edit")
    assert_no_changes -> { @resource.reload.name } do
      assert_response_forbidden(:patch, "/admin/reservation_resources/#{@resource.id}", reservation_resource: { name: "不可" })
    end
  end

  test "viewer can read both resources but cannot open or submit write forms" do
    sign_in_as_role(:viewer)

    assert_readable("customers", @customer)
    assert_response_forbidden(:get, "/admin/customers/new")
    assert_no_difference("Customer.count") do
      assert_response_forbidden(:post, "/admin/customers", customer: { name: "不可" })
    end
    assert_response_forbidden(:get, "/admin/customers/#{@customer.id}/edit")
    assert_no_changes -> { @customer.reload.name } do
      assert_response_forbidden(:patch, "/admin/customers/#{@customer.id}", customer: { name: "不可" })
    end

    assert_readable("reservation_resources", @resource)
    assert_response_forbidden(:get, "/admin/reservation_resources/new")
    assert_no_difference("ReservationResource.count") do
      assert_response_forbidden(:post, "/admin/reservation_resources", reservation_resource: { name: "不可", kind: "room", capacity: 1 })
    end
    assert_response_forbidden(:get, "/admin/reservation_resources/#{@resource.id}/edit")
    assert_no_changes -> { @resource.reload.name } do
      assert_response_forbidden(:patch, "/admin/reservation_resources/#{@resource.id}", reservation_resource: { name: "不可" })
    end
  end

  test "role helpers grant the permission seed design for master resources" do
    admin = account_with_role(:admin)
    operator = account_with_role(:operator)
    viewer = account_with_role(:viewer)

    assert AnneAccess.can?(admin, :manage, :customers)
    assert AnneAccess.can?(admin, :manage, :reservation_resources)

    assert AnneAccess.can?(operator, :index, :customers)
    assert AnneAccess.can?(operator, :new, :customers)
    assert AnneAccess.can?(operator, :edit, :customers)
    assert AnneAccess.can?(operator, :index, :reservation_resources)
    assert_not AnneAccess.can?(operator, :new, :reservation_resources)
    assert_not AnneAccess.can?(operator, :edit, :reservation_resources)

    assert AnneAccess.can?(viewer, :index, :customers)
    assert AnneAccess.can?(viewer, :index, :reservation_resources)
    assert_not AnneAccess.can?(viewer, :new, :customers)
    assert_not AnneAccess.can?(viewer, :edit, :reservation_resources)
  end

  test "destroy is unavailable for every master resource" do
    sign_in_as_role(:admin)

    delete "/admin/customers/#{@customer.id}"
    assert_response :not_found

    delete "/admin/reservation_resources/#{@resource.id}"
    assert_response :not_found
    assert Customer.exists?(@customer.id)
    assert ReservationResource.exists?(@resource.id)
  end

  private
    def assert_master_actions(resource)
      assert_equal %i[index show new create edit update], resource.actions
      assert_not resource.action?(:destroy)
    end

    def assert_readable(resource_name, record)
      assert_response_allowed(:get, "/admin/#{resource_name}")
      assert_response_allowed(:get, "/admin/#{resource_name}/#{record.id}")
    end

    def assert_response_allowed(method, path, params = {})
      public_send(method, path, params:)
      assert_response(method == :get ? :success : :redirect)
    end

    def assert_response_forbidden(method, path, params = {})
      public_send(method, path, params:)
      assert_response :forbidden
    end
end
