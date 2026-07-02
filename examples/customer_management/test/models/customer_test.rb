require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "organization customer displays organization name" do
    organization = Organization.new(name: "サンプル株式会社")
    customer = Customer.new(customer_number: "C-ORG", kind: "organization", organization:, status: "active")

    assert_predicate customer, :valid?
    assert_equal "サンプル株式会社（法人）", customer.display_name
  end

  test "person customer displays person name" do
    person = Person.new(name: "佐藤 花子")
    customer = Customer.new(customer_number: "C-PER", kind: "person", person:, status: "active")

    assert_predicate customer, :valid?
    assert_equal "佐藤 花子（個人）", customer.display_name
  end

  test "kind requires matching target only" do
    person = Person.new(name: "佐藤 花子")
    organization = Organization.new(name: "サンプル株式会社")
    customer = Customer.new(customer_number: "C-MIX", kind: "person", person:, organization:, status: "active")

    assert_not customer.valid?
    assert_includes customer.errors[:organization], "は個人顧客では選択できません"
  end
end
