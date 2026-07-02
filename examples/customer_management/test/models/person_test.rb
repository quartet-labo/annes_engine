require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "display name returns person name" do
    person = Person.new(name: "佐藤 花子")

    assert_equal "佐藤 花子", person.display_name
  end

  test "email must be valid when present" do
    person = Person.new(name: "佐藤 花子", email: "invalid")

    assert_not person.valid?
    assert_not_empty person.errors[:email]
  end
end
