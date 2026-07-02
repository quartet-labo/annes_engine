require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "display name returns organization name" do
    organization = Organization.new(name: "サンプル株式会社")

    assert_equal "サンプル株式会社", organization.display_name
  end

  test "destroy removes related customers, contacts, and projects" do
    organization = Organization.create!(name: "サンプル株式会社")
    person = Person.create!(name: "山田 太郎", email: "customer@example.com")
    customer = Customer.create!(customer_number: "C-TEST", kind: "organization", organization:, status: "active")
    contact = customer.customer_contacts.create!(person:, role: "primary", email: person.email, primary: true)
    project = customer.projects.create!(project_number: "PJ-TEST", name: "導入支援", status: "active")

    organization.destroy!

    assert_not Customer.exists?(customer.id)
    assert_not CustomerContact.exists?(contact.id)
    assert_not Project.exists?(project.id)
  end
end
