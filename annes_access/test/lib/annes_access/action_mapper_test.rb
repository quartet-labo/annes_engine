require_relative "../../test_helper"

class AnnesAccess::ActionMapperTest < AnnesAccess::TestCase
  test "maps controller actions to access actions" do
    mapper = AnnesAccess::ActionMapper.new

    assert_equal "read", mapper.map(:index)
    assert_equal "read", mapper.map("show")
    assert_equal "create", mapper.map(:new)
    assert_equal "update", mapper.map(:edit)
    assert_equal "destroy", mapper.map(:destroy)
  end
end
