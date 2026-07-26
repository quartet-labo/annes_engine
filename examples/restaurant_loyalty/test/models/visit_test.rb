require "test_helper"

class VisitTest < ActiveSupport::TestCase
  test "records a customer visit" do
    visit = Visit.create!(customer: Customer.create!(name: "佐藤 花子"), visited_at: Time.current)

    assert_predicate visit, :persisted?
  end
end
