require "test_helper"

class AdminResourcesTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      email: "admin@example.com",
      name: "Admin",
      role: "admin",
      password: "password",
      password_confirmation: "password"
    )

    organization = Organization.create!(name: "サンプル株式会社")
    person = Person.create!(name: "山田 太郎", email: "contact@example.com")
    customer = Customer.create!(customer_number: "C-ADMIN", kind: "organization", organization:, status: "active")
    customer.customer_contacts.create!(person:, role: "primary", email: person.email, primary: true)
    customer.projects.create!(project_number: "PJ-ADMIN", name: "管理画面確認", status: "active")
  end

  test "admin customer resources render" do
    post admin_session_path, params: { email: @admin.email, password: "password" }

    {
      "/admin/customers" => "顧客",
      "/admin/persons" => "個人",
      "/admin/organizations" => "組織",
      "/admin/customer_contacts" => "顧客連絡先",
      "/admin/projects" => "案件"
    }.each do |path, label|
      get path

      assert_response :success
      assert_includes response.body, label
    end
  end

  test "admin resources are loaded in navigation order" do
    assert_equal %w[customers persons organizations customer_contacts projects], AnneAdmin.configuration.resources.map(&:name)
    assert_equal %i[customer_number kind person_id organization_id status source memo created_at], AnneAdmin.configuration.resources.fetch(:customers).fields.map(&:name)
  end
end
