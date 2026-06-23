require_relative "../../test_helper"

class AnneAdmin::AuthorizationAdapterTest < AnneAdmin::TestCase
  test "delegates authorization to block" do
    adapter = AnneAdmin::AuthorizationAdapter.new(->(context) { context[:action] == :show })

    assert adapter.authorized?(action: :show)
    assert_not adapter.authorized?(action: :edit)
  end
end
