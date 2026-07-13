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
    sign_in_with_permissions(
      role_key: "admin",
      permissions: {
        "customers" => %w[manage],
        "reservation_resources" => %w[manage]
      }
    )

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
    sign_in_with_permissions(
      role_key: "operator",
      permissions: {
        "customers" => %w[read create update],
        "reservation_resources" => %w[read]
      }
    )

    assert_readable("customers", @customer)
    assert_response_allowed(:get, "/admin/customers/new")
    assert_response_allowed(:post, "/admin/customers", customer: { name: "担当者登録" })
    assert_response_allowed(:get, "/admin/customers/#{@customer.id}/edit")
    assert_response_allowed(:patch, "/admin/customers/#{@customer.id}", customer: { memo: "担当者更新" })

    assert_readable("reservation_resources", @resource)
    assert_response_forbidden(:get, "/admin/reservation_resources/new")
    assert_response_forbidden(:post, "/admin/reservation_resources", reservation_resource: { name: "不可", kind: "room", capacity: 1 })
    assert_response_forbidden(:get, "/admin/reservation_resources/#{@resource.id}/edit")
    assert_response_forbidden(:patch, "/admin/reservation_resources/#{@resource.id}", reservation_resource: { name: "不可" })
  end

  test "viewer can read both resources but cannot open or submit write forms" do
    sign_in_with_permissions(
      role_key: "viewer",
      permissions: {
        "customers" => %w[read],
        "reservation_resources" => %w[read]
      }
    )

    assert_readable("customers", @customer)
    assert_response_forbidden(:get, "/admin/customers/new")
    assert_response_forbidden(:post, "/admin/customers", customer: { name: "不可" })
    assert_response_forbidden(:get, "/admin/customers/#{@customer.id}/edit")
    assert_response_forbidden(:patch, "/admin/customers/#{@customer.id}", customer: { name: "不可" })

    assert_readable("reservation_resources", @resource)
    assert_response_forbidden(:get, "/admin/reservation_resources/new")
    assert_response_forbidden(:post, "/admin/reservation_resources", reservation_resource: { name: "不可", kind: "room", capacity: 1 })
    assert_response_forbidden(:get, "/admin/reservation_resources/#{@resource.id}/edit")
    assert_response_forbidden(:patch, "/admin/reservation_resources/#{@resource.id}", reservation_resource: { name: "不可" })
  end

  test "destroy is unavailable for every master resource" do
    sign_in_with_permissions(
      role_key: "admin",
      permissions: {
        "customers" => %w[manage],
        "reservation_resources" => %w[manage]
      }
    )

    delete "/admin/customers/#{@customer.id}"
    assert_response :not_found

    delete "/admin/reservation_resources/#{@resource.id}"
    assert_response :not_found
    assert Customer.exists?(@customer.id)
    assert ReservationResource.exists?(@resource.id)
  end

  private
    def assert_master_actions(resource)
      assert_equal %i[index show new create edit update], resource.actions.sort_by { |action| %i[index show new create edit update].index(action) }
      assert_not resource.action?(:destroy)
    end

    def assert_readable(resource_name, record)
      assert_response_allowed(:get, "/admin/#{resource_name}")
      assert_response_allowed(:get, "/admin/#{resource_name}/#{record.id}")
    end

    def assert_response_allowed(method, path, params = {})
      public_send(method, path, params:)
      assert_response :success unless response.redirect?
    end

    def assert_response_forbidden(method, path, params = {})
      public_send(method, path, params:)
      assert_response :forbidden
    end

    def sign_in_with_permissions(role_key:, permissions:)
      account = Account.create!(
        email: "#{role_key}@example.com",
        password: "password-1234",
        password_confirmation: "password-1234"
      )
      role = AnneAccess::Role.create!(key: role_key, name: role_key.humanize, system: true)

      permissions.each do |resource, actions|
        actions.each do |action|
          permission = AnneAccess::Permission.create!(
            key: "#{resource}.#{action}",
            resource:,
            action:
          )
          AnneAccess::RolePermission.create!(role:, permission:)
        end
      end

      AnneAccess::Assignment.create!(principal: account, role:)
      post admin_session_path, params: { email: account.email, password: "password-1234" }
      assert_redirected_to admin_root_path
    end
end
