require "test_helper"

class CustomerContactTest < ActiveSupport::TestCase
  test "display name includes person and role label" do
    person = Person.new(name: "山田 太郎")
    contact = CustomerContact.new(person:, role: "billing")

    assert_equal "山田 太郎（請求担当）", contact.display_name
  end

  test "role must be known" do
    contact = CustomerContact.new(role: "unknown", primary: false)

    assert_not contact.valid?
    assert_not_empty contact.errors[:role]
  end
end
