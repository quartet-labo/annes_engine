require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "status label returns Japanese label" do
    project = Project.new(status: "active")

    assert_equal "進行中", project.status_label
  end

  test "project belongs to customer party" do
    organization = Organization.new(name: "サンプル株式会社")
    customer = Customer.new(customer_number: "C-PROJ", kind: "organization", organization:, status: "active")
    project = Project.new(customer:, project_number: "PJ-001", name: "導入支援", status: "active")

    assert_equal "サンプル株式会社（法人）", project.customer.display_name
  end
end
