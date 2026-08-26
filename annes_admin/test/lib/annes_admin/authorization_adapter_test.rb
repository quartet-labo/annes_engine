require_relative "../../test_helper"

class AnnesAdmin::AuthorizationAdapterTest < AnnesAdmin::TestCase
  test "delegates authorization to block" do
    adapter = AnnesAdmin::AuthorizationAdapter.new(->(context) { context[:action] == :show })

    assert adapter.authorized?(action: :show)
    assert_not adapter.authorized?(action: :edit)
  end
end
